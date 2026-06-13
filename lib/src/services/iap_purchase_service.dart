import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:tangent_sdk/src/core/exceptions/tangent_sdk_exception.dart';
import 'package:tangent_sdk/src/core/model/product.dart';
import 'package:tangent_sdk/src/core/model/purchased_product_details.dart';
import 'package:tangent_sdk/src/core/types/result.dart';
import 'package:tangent_sdk/src/core/utils/app_logger.dart';

const _tag = 'IAPPurchaseService';

/// Stream-first wrapper around [InAppPurchase].
///
/// The store's `purchaseStream` is the single source of truth: every
/// transaction — whether initiated this session, deferred (Ask to Buy),
/// or redelivered after a crash — flows through one path:
/// deliver content → complete the transaction.
///
/// Per StoreKit/Play guidance, a transaction is only completed after the
/// content has been delivered. If delivery fails, the transaction is left
/// unfinished and the store redelivers it on next launch.
class IAPPurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Awaited before completing each purchased transaction. See
  /// [PurchaseDeliveryHandler]. When null, transactions are completed
  /// immediately (legacy behavior for apps without out-of-band content).
  PurchaseDeliveryHandler? deliveryHandler;

  /// In-flight purchase requests awaiting a terminal stream event,
  /// keyed by productID.
  final Map<String, Completer<Result<Product>>> _pendingRequests = {};
  final Map<String, Product> _pendingProducts = {};

  /// Queue guaranteeing transactions are delivered/completed one at a time,
  /// in stream order, even though the stream listener cannot be awaited.
  Future<void> _processingChain = Future.value();

  final StreamController<PurchasedProductDetails> _purchaseUpdatedController =
      StreamController<PurchasedProductDetails>.broadcast();

  /// Emits after a transaction has been delivered AND completed.
  /// Intended for passive consumers (success dialogs, analytics) —
  /// content granting belongs in [deliveryHandler].
  Stream<PurchasedProductDetails> get purchaseUpdatedStream => _purchaseUpdatedController.stream;

  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
      AppLogger.error('In-App Purchase is not available on this device', tag: _tag);
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        AppLogger.error('Purchase stream error', error: error, tag: _tag);
        _failAllPending(
          Failure(PurchaseException('stream_error', message: error.toString(), code: 'purchase_error')),
        );
      },
    );

    AppLogger.info('IAP Purchase Service initialized', tag: _tag);
  }

  Future<Result<List<Product>>> getProducts(List<String> productIds) async {
    try {
      final response = await _iap.queryProductDetails(productIds.toSet());

      if (response.notFoundIDs.isNotEmpty) {
        AppLogger.error('Products not found: ${response.notFoundIDs.join(', ')}', tag: _tag);
      }

      final products = response.productDetails.map((details) {
        return Product(
          id: details.id,
          title: details.title,
          description: details.description,
          price: details.rawPrice,
          priceString: details.price,
          currencyCode: details.currencyCode,
          productDetails: details,
        );
      }).toList();

      return Success(products);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get products', error: e, stackTrace: stackTrace, tag: _tag);
      return Failure(ServiceOperationException('getProducts', e));
    }
  }

  /// Purchase a subscription or non-consumable product.
  ///
  /// The returned future resolves only after the transaction has been
  /// delivered (see [deliveryHandler]) and completed with the store.
  Future<Result<Product>> purchaseProduct(Product product) {
    return _purchase(product, consumable: false);
  }

  /// Purchase a consumable product (coins, credits, …).
  ///
  /// Uses `buyConsumable` so the purchase is consumed on Android and can
  /// be bought again. The returned future resolves only after delivery
  /// and completion, like [purchaseProduct].
  Future<Result<Product>> purchaseConsumable(Product product) {
    return _purchase(product, consumable: true);
  }

  Future<Result<Product>> _purchase(Product product, {required bool consumable}) async {
    try {
      if (product.productDetails == null) {
        return const Failure(
          PurchaseException('purchase', message: 'ProductDetails is required for purchasing', code: 'missing_details'),
        );
      }

      if (_pendingRequests.containsKey(product.id)) {
        return const Failure(
          PurchaseException('purchase', message: 'A purchase for this product is already in progress', code: 'purchase_in_progress'),
        );
      }

      final completer = Completer<Result<Product>>();
      _pendingRequests[product.id] = completer;
      _pendingProducts[product.id] = product;

      final purchaseParam = PurchaseParam(productDetails: product.productDetails!);
      final started = consumable
          ? await _iap.buyConsumable(purchaseParam: purchaseParam)
          : await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!started) {
        _removePending(product.id);
        return const Failure(
          PurchaseException('purchase', message: 'Failed to start purchase', code: 'purchase_error'),
        );
      }

      return await completer.future;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to purchase product', error: e, stackTrace: stackTrace, tag: _tag);
      _removePending(product.id);
      return Failure(
        PurchaseException('purchase', message: e.toString(), code: 'purchase_error', originalError: e),
      );
    }
  }

  Future<Result<bool>> restorePurchases() async {
    try {
      await _iap.restorePurchases();
      return const Success(true);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to restore purchases', error: e, stackTrace: stackTrace, tag: _tag);
      return Failure(ServiceOperationException('restorePurchases', e));
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      // Chain sequentially so deliver→complete finishes for one transaction
      // before the next is processed.
      _processingChain = _processingChain.then((_) => _processTransaction(purchaseDetails));
    }
  }

  Future<void> _processTransaction(PurchaseDetails purchaseDetails) async {
    switch (purchaseDetails.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _handleSuccessfulPurchase(purchaseDetails);
        break;
      case PurchaseStatus.error:
        _handlePurchaseError(purchaseDetails);
        await _completeWithStore(purchaseDetails);
        break;
      case PurchaseStatus.canceled:
        _handlePurchaseCancelled(purchaseDetails);
        await _completeWithStore(purchaseDetails);
        break;
      case PurchaseStatus.pending:
        AppLogger.info('Purchase pending: ${purchaseDetails.productID}', tag: _tag);
        break;
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    AppLogger.info(
      'Purchase ${purchaseDetails.status.name}: ${purchaseDetails.productID} (txn: ${purchaseDetails.purchaseID})',
      tag: _tag,
    );

    final details = PurchasedProductDetails(
      productID: purchaseDetails.productID,
      purchaseID: purchaseDetails.purchaseID,
      transactionDate: purchaseDetails.transactionDate,
      status: purchaseDetails.status,
      verificationData: purchaseDetails.verificationData.serverVerificationData,
      verificationSource: purchaseDetails.verificationData.source,
    );

    var delivered = true;
    if (deliveryHandler != null) {
      try {
        delivered = await deliveryHandler!(details);
      } catch (e, stackTrace) {
        AppLogger.error('Purchase delivery handler threw', error: e, stackTrace: stackTrace, tag: _tag);
        delivered = false;
      }
    }

    // Restores must always be completed: there is no content to deliver
    // (consumed consumables are never replayed by the stores), and leaving
    // them unfinished makes them replay on every launch.
    final isRestore = purchaseDetails.status == PurchaseStatus.restored;

    if (!delivered && !isRestore) {
      // Leave the transaction unfinished — the store redelivers it on next
      // launch, which is the retry mechanism for failed content delivery.
      AppLogger.error(
        'Delivery failed for ${purchaseDetails.productID}; transaction left unfinished for redelivery',
        tag: _tag,
      );
      _resolvePending(
        purchaseDetails.productID,
        const Failure(
          PurchaseException(
            'purchase',
            message: 'Purchase succeeded but content delivery failed; it will be retried on next launch',
            code: 'delivery_failed',
          ),
        ),
      );
      return;
    }

    await _completeWithStore(purchaseDetails);

    if (!_purchaseUpdatedController.isClosed) {
      _purchaseUpdatedController.add(details);
    }

    final pendingProduct = _pendingProducts[purchaseDetails.productID];
    if (pendingProduct != null) {
      _resolvePending(purchaseDetails.productID, Success(pendingProduct));
    } else {
      AppLogger.info('Out-of-band purchase processed: ${purchaseDetails.productID}', tag: _tag);
    }
  }

  /// Deliver a purchase completed OUTSIDE the in_app_purchase pipeline
  /// (e.g. a transaction made by a Superwall-presented paywall, which
  /// Superwall finishes with the store itself).
  ///
  /// Runs the same delivery contract as store-stream transactions — awaits
  /// [deliveryHandler], then emits on [purchaseUpdatedStream] — but never
  /// calls completePurchase, since the external SDK owns the transaction.
  /// Granting must be idempotent on [PurchasedProductDetails.purchaseID]:
  /// unlike store-stream transactions, a failed delivery here is NOT
  /// redelivered by the store on next launch.
  Future<void> deliverExternalPurchase(PurchasedProductDetails details) async {
    AppLogger.info('Delivering external purchase: $details', tag: _tag);

    if (deliveryHandler != null) {
      try {
        final delivered = await deliveryHandler!(details);
        if (!delivered) {
          AppLogger.error(
            'Delivery handler reported failure for external purchase ${details.productID}',
            tag: _tag,
          );
          return;
        }
      } catch (e, stackTrace) {
        AppLogger.error('Delivery handler threw for external purchase', error: e, stackTrace: stackTrace, tag: _tag);
        return;
      }
    }

    if (!_purchaseUpdatedController.isClosed) {
      _purchaseUpdatedController.add(details);
    }
  }

  Future<void> _completeWithStore(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(purchaseDetails);
      } catch (e, stackTrace) {
        AppLogger.error('Failed to complete purchase with store', error: e, stackTrace: stackTrace, tag: _tag);
      }
    }
  }

  void _handlePurchaseError(PurchaseDetails purchaseDetails) {
    AppLogger.error(
      'Purchase error: ${purchaseDetails.productID} — ${purchaseDetails.error?.message}',
      tag: _tag,
    );
    _resolvePending(
      purchaseDetails.productID,
      Failure(
        PurchaseException(
          'purchase',
          message: purchaseDetails.error?.message ?? 'Unknown error',
          code: 'purchase_error',
          originalError: purchaseDetails.error,
        ),
      ),
    );
  }

  void _handlePurchaseCancelled(PurchaseDetails purchaseDetails) {
    AppLogger.info('Purchase cancelled: ${purchaseDetails.productID}', tag: _tag);
    _resolvePending(
      purchaseDetails.productID,
      const Failure(
        PurchaseException('purchase', message: 'User cancelled', code: 'user_cancelled'),
      ),
    );
  }

  void _resolvePending(String productID, Result<Product> result) {
    final completer = _pendingRequests.remove(productID);
    _pendingProducts.remove(productID);
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  void _removePending(String productID) {
    _pendingRequests.remove(productID);
    _pendingProducts.remove(productID);
  }

  void _failAllPending(Result<Product> result) {
    for (final productID in List.of(_pendingRequests.keys)) {
      _resolvePending(productID, result);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _failAllPending(
      const Failure(PurchaseException('purchase', message: 'Service disposed', code: 'disposed')),
    );
    _purchaseUpdatedController.close();
  }
}
