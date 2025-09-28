import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart' hide LogLevel, StoreProduct;
import 'package:tangent_sdk/src/core/model/product.dart' as product;
import 'package:tangent_sdk/src/core/utils/app_logger.dart' as app_logger;

typedef PurchaseCallback = Future<void> Function(product.Product product);

class RCPurchaseController extends PurchaseController {
  static const String _tag = '💳 RCPurchaseController';
  final PurchaseCallback _onSubscriptionPurchaseCompleted;
  final PurchaseCallback _onConsumablePurchaseCompleted;

  RCPurchaseController(this._onSubscriptionPurchaseCompleted, this._onConsumablePurchaseCompleted);

  /// MARK: Configure and sync subscription Status
  /// Makes sure that Superwall knows the customers subscription status by
  /// changing `Superwall.shared.subscriptionStatus`
  Future<void> configureAndSyncSubscriptionStatus() async {
    app_logger.AppLogger.info('Configuring RevenueCat and syncing subscription status', tag: _tag);
    // Configure RevenueCat
    await Purchases.setLogLevel(LogLevel.debug);
    //! Already configured
    //! final configuration = Platform.isIOS ? PurchasesConfiguration(iOSApiKey) : PurchasesConfiguration('androidApiKey');
    //! await Purchases.configure(configuration);

    Purchases.addCustomerInfoUpdateListener((customerInfo) async {
      final entitlements = customerInfo.entitlements.active.keys.map((id) => Entitlement(id: id)).toSet();
      final hasActiveEntitlementOrSubscription = customerInfo.hasActiveEntitlementOrSubscription();

      if (hasActiveEntitlementOrSubscription) {
        app_logger.AppLogger.info(
          'Setting Superwall subscription status to active with entitlements: ${entitlements.map((e) => e.id).join(", ")}',
          tag: _tag,
        );
        await Superwall.shared.setSubscriptionStatus(SubscriptionStatusActive(entitlements: entitlements));
      } else {
        app_logger.AppLogger.info('Setting Superwall subscription status to inactive', tag: _tag);
        await Superwall.shared.setSubscriptionStatus(SubscriptionStatusInactive());
      }
    });
  }

  // MARK: Handle Purchases

  /// Makes a purchase from App Store with RevenueCat and returns its
  /// result. This gets called when someone tries to purchase a product on
  /// one of your paywalls from iOS.
  @override
  Future<PurchaseResult> purchaseFromAppStore(String productId) async {
    app_logger.AppLogger.info('Starting App Store purchase for product: $productId', tag: _tag);
    // Find products matching productId from RevenueCat
    final products = await PurchasesAdditions.getAllProducts([productId]);

    // Get first product for product ID (this will properly throw if empty)
    final storeProduct = products.firstOrNull;

    if (storeProduct == null) {
      app_logger.AppLogger.error('Failed to find store product for $productId', tag: _tag);
      return PurchaseResult.failed('Failed to find store product for $productId');
    }

    final isSubscription = storeProduct.productCategory == ProductCategory.subscription;
    if (isSubscription) {
      return _purchaseSubscriptionProduct(storeProduct);
    } else {
      return _purchaseConsumableProduct(storeProduct);
    }
  }

  // MARK: Handle Purchases (Android)
  /// Makes a purchase from Google Play with RevenueCat and returns its
  /// result. This gets called when someone tries to purchase a product on
  /// one of your paywalls from Android.
  @override
  Future<PurchaseResult> purchaseFromGooglePlay(String productId, String? basePlanId, String? offerId) async {
    app_logger.AppLogger.info(
      'Starting Google Play purchase for product: $productId, basePlan: $basePlanId, offer: $offerId',
      tag: _tag,
    );
    // Find products matching productId from RevenueCat
    final List<StoreProduct> products = await PurchasesAdditions.getAllProducts([productId]);

    // Choose the product which matches the given base plan.
    // If no base plan set, select first product or fail.
    final String storeProductId = "$productId:$basePlanId";

    StoreProduct? matchingProduct;
    for (final product in products) {
      if (product.identifier == storeProductId) {
        matchingProduct = product;
        break;
      }
    }

    // If a matching product is not found, then try to get the first product from the list.
    final StoreProduct? storeProduct = matchingProduct ?? (products.isNotEmpty ? products.first : null);

    // If no product is found (either matching or the first one), return a failed purchase result.
    if (storeProduct == null) {
      app_logger.AppLogger.error('Product not found for productId: $productId, basePlanId: $basePlanId', tag: _tag);
      return PurchaseResult.failed("Product not found");
    }

    switch (storeProduct.productCategory) {
      case ProductCategory.subscription:
        final SubscriptionOption? subscriptionOption = await _fetchGooglePlaySubscriptionOption(
          storeProduct,
          basePlanId,
          offerId,
        );
        if (subscriptionOption == null) {
          return PurchaseResult.failed("Valid subscription option not found for product.");
        }
        return _purchaseSubscriptionOption(subscriptionOption);
      case ProductCategory.nonSubscription:
        return _purchaseConsumableProduct(storeProduct);
      case null:
        return PurchaseResult.failed("Unable to determine product category");
    }
  }

  // MARK: Subscriptions
  Future<PurchaseResult> _purchaseSubscriptionProduct(StoreProduct storeProduct) async {
    try {
      final customerInfo = await Purchases.purchaseStoreProduct(storeProduct);
      if (customerInfo.hasActiveEntitlementOrSubscription()) {
        final product = _storeProductToProduct(storeProduct);
        _onSubscriptionPurchaseCompleted(product);
        return PurchaseResult.purchased;
      } else {
        return PurchaseResult.failed("No active subscriptions found.");
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) return PurchaseResult.cancelled;
      if (errorCode == PurchasesErrorCode.paymentPendingError) return PurchaseResult.pending;
      return PurchaseResult.failed(e.message ?? "Purchase failed");
    }
  }

  Future<PurchaseResult> _purchaseSubscriptionOption(SubscriptionOption subscriptionOption) async {
    try {
      final customerInfo = await Purchases.purchaseSubscriptionOption(subscriptionOption);
      if (customerInfo.hasActiveEntitlementOrSubscription()) {
        final product = await _subscriptionOptionToProduct(subscriptionOption);
        _onSubscriptionPurchaseCompleted(product);
        return PurchaseResult.purchased;
      } else {
        return PurchaseResult.failed("No active subscriptions found.");
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) return PurchaseResult.cancelled;
      if (errorCode == PurchasesErrorCode.paymentPendingError) return PurchaseResult.pending;
      return PurchaseResult.failed(e.message ?? "Purchase failed");
    }
  }

  // MARK: Consumables (coins)
  Future<PurchaseResult> _purchaseConsumableProduct(StoreProduct storeProduct) async {
    try {
      await Purchases.purchaseStoreProduct(storeProduct);
      final product = _storeProductToProduct(storeProduct);
      _onConsumablePurchaseCompleted(product);

      // ✅ If we get here without an exception, the purchase was validated by Apple/Google via RevenueCat

      return PurchaseResult.purchased;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) return PurchaseResult.cancelled;
      if (errorCode == PurchasesErrorCode.paymentPendingError) return PurchaseResult.pending;
      return PurchaseResult.failed(e.message ?? "Consumable purchase failed");
    }
  }

  /// MARK: Handle Restores
  /// Makes a restore with RevenueCat and returns `.restored`, unless an error is thrown.
  /// This gets called when someone tries to restore purchases on one of your paywalls.
  @override
  Future<RestorationResult> restorePurchases() async {
    app_logger.AppLogger.info('Starting purchase restoration', tag: _tag);
    try {
      final info = await Purchases.restorePurchases();
      final hasSub = info.hasActiveEntitlementOrSubscription();
      app_logger.AppLogger.info('Purchase restoration completed successfully', tag: _tag);
      await Superwall.shared.setSubscriptionStatus(
        hasSub
            ? SubscriptionStatusActive(
              entitlements: info.entitlements.active.keys.map((id) => Entitlement(id: id)).toSet(),
            )
            : SubscriptionStatusInactive(),
      );
      return hasSub ? RestorationResult.restored : RestorationResult.failed("No active subscriptions to restore.");
    } on PlatformException catch (e, stackTrace) {
      // Error restoring purchases
      app_logger.AppLogger.error('Purchase restoration failed', tag: _tag, error: e, stackTrace: stackTrace);
      return RestorationResult.failed(e.message ?? "Restore failed in RCPurchaseController");
    } catch (e, stackTrace) {
      app_logger.AppLogger.error(
        'Unexpected error during purchase restoration',
        tag: _tag,
        error: e,
        stackTrace: stackTrace,
      );
      return RestorationResult.failed("Unexpected error during purchase restoration");
    }
  }

  // MARK: Helpers
  /// Converts a StoreProduct to our internal Product model
  product.Product _storeProductToProduct(StoreProduct storeProduct) {
    return product.Product(
      id: storeProduct.identifier,
      title: storeProduct.title,
      description: storeProduct.description,
      price: storeProduct.price,
      priceString: storeProduct.priceString,
      currencyCode: storeProduct.currencyCode,
      storeProduct: storeProduct,
    );
  }

  /// Converts a SubscriptionOption to our internal Product model
  Future<product.Product> _subscriptionOptionToProduct(SubscriptionOption subscriptionOption) async {
    // Fetch the store product for this subscription option
    final products = await PurchasesAdditions.getAllProducts([subscriptionOption.productId]);
    final storeProduct = products.firstOrNull;

    if (storeProduct == null) {
      // Fallback with minimal product info if we can't fetch the full product
      return product.Product(
        id: subscriptionOption.productId,
        title: subscriptionOption.productId,
        description: '',
        price:
            subscriptionOption.pricingPhases.isNotEmpty
                ? subscriptionOption.pricingPhases.first.price.amountMicros / 1000000.0
                : 0.0,
        priceString:
            subscriptionOption.pricingPhases.isNotEmpty ? subscriptionOption.pricingPhases.first.price.formatted : '',
        currencyCode:
            subscriptionOption.pricingPhases.isNotEmpty
                ? subscriptionOption.pricingPhases.first.price.currencyCode
                : 'USD',
        storeProduct: subscriptionOption,
      );
    }

    return product.Product(
      id: subscriptionOption.productId,
      title: storeProduct.title,
      description: storeProduct.description,
      price: storeProduct.price,
      priceString: storeProduct.priceString,
      currencyCode: storeProduct.currencyCode,
      storeProduct: storeProduct,
    );
  }

  Future<SubscriptionOption?> _fetchGooglePlaySubscriptionOption(
    StoreProduct storeProduct,
    String? basePlanId,
    String? offerId,
  ) async {
    final subscriptionOptions = storeProduct.subscriptionOptions;
    if (subscriptionOptions != null && subscriptionOptions.isNotEmpty) {
      final subscriptionOptionId = _buildSubscriptionOptionId(basePlanId, offerId);
      SubscriptionOption? subscriptionOption;
      for (final option in subscriptionOptions) {
        if (option.id == subscriptionOptionId) {
          subscriptionOption = option;
          break;
        }
      }
      subscriptionOption ??= storeProduct.defaultOption;
      return subscriptionOption;
    }
    return null;
  }
}

String _buildSubscriptionOptionId(String? basePlanId, String? offerId) {
  String result = '';
  if (basePlanId != null) result += basePlanId;
  if (offerId != null) {
    if (basePlanId != null) result += ':';
    result += offerId;
  }
  return result;
}

extension CustomerInfoAdditions on CustomerInfo {
  bool hasActiveEntitlementOrSubscription() {
    return (activeSubscriptions.isNotEmpty || entitlements.active.isNotEmpty);
  }
}

extension PurchasesAdditions on Purchases {
  static Future<List<StoreProduct>> getAllProducts(List<String> productIdentifiers) async {
    final subscriptionProducts = await Purchases.getProducts(
      productIdentifiers,
      productCategory: ProductCategory.subscription,
    );
    final nonSubscriptionProducts = await Purchases.getProducts(
      productIdentifiers,
      productCategory: ProductCategory.nonSubscription,
    );
    return [...subscriptionProducts, ...nonSubscriptionProducts];
  }
}
