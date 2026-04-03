import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:tangent_sdk/src/core/exceptions/tangent_sdk_exception.dart';
import 'package:tangent_sdk/src/core/model/product.dart';
import 'package:tangent_sdk/src/core/types/result.dart';
import 'package:tangent_sdk/src/core/utils/app_logger.dart';

const _tag = 'IAPPurchaseService';

class IAPPurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<Result<Product>>? _purchaseCompleter;
  Product? _pendingProduct;

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
        _completePurchase(
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

  Future<Result<Product>> purchaseProduct(Product product) async {
    try {
      if (product.productDetails == null) {
        return const Failure(
          PurchaseException('purchase', message: 'ProductDetails is required for purchasing', code: 'missing_details'),
        );
      }

      _pendingProduct = product;
      _purchaseCompleter = Completer<Result<Product>>();

      final purchaseParam = PurchaseParam(productDetails: product.productDetails!);
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!started) {
        _pendingProduct = null;
        final completer = _purchaseCompleter;
        _purchaseCompleter = null;
        if (completer != null && !completer.isCompleted) {
          return const Failure(
            PurchaseException('purchase', message: 'Failed to start purchase', code: 'purchase_error'),
          );
        }
      }

      return await _purchaseCompleter!.future;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to purchase product', error: e, stackTrace: stackTrace, tag: _tag);
      _pendingProduct = null;
      _purchaseCompleter = null;
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
      switch (purchaseDetails.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(purchaseDetails);
          break;
        case PurchaseStatus.error:
          _handlePurchaseError(purchaseDetails);
          break;
        case PurchaseStatus.canceled:
          _handlePurchaseCancelled(purchaseDetails);
          break;
        case PurchaseStatus.pending:
          AppLogger.info('Purchase pending: ${purchaseDetails.productID}', tag: _tag);
          break;
      }

      if (purchaseDetails.pendingCompletePurchase) {
        _iap.completePurchase(purchaseDetails);
      }
    }
  }

  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    AppLogger.info('Purchase successful: ${purchaseDetails.productID}', tag: _tag);

    if (_pendingProduct != null && _pendingProduct!.id == purchaseDetails.productID) {
      _completePurchase(Success(_pendingProduct!));
    } else {
      // Restored or external purchase — no pending product
      AppLogger.info('Purchase completed without pending product: ${purchaseDetails.productID}', tag: _tag);
    }
  }

  void _handlePurchaseError(PurchaseDetails purchaseDetails) {
    AppLogger.error(
      'Purchase error: ${purchaseDetails.productID} — ${purchaseDetails.error?.message}',
      tag: _tag,
    );
    _completePurchase(
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
    _completePurchase(
      const Failure(
        PurchaseException('purchase', message: 'User cancelled', code: 'user_cancelled'),
      ),
    );
  }

  void _completePurchase(Result<Product> result) {
    _pendingProduct = null;
    final completer = _purchaseCompleter;
    _purchaseCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
