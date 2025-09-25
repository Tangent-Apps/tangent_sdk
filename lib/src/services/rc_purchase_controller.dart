import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart' hide LogLevel, StoreProduct;

import 'package:tangent_sdk/src/core/utils/app_logger.dart' as app_logger;

typedef SuperwallPurchaseCallback = Future<void> Function(String productId);

class RCPurchaseController extends PurchaseController {
  static const String _tag = '💳 RCPurchaseController';
  final SuperwallPurchaseCallback _onPurchaseCompleted;

  RCPurchaseController(this._onPurchaseCompleted);

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

    // Listen for changes
    app_logger.AppLogger.info('Setting up CustomerInfo update listener', tag: _tag);
    Purchases.addCustomerInfoUpdateListener((customerInfo) async {
      // Gets called whenever new CustomerInfo is available
      final entitlements = customerInfo.entitlements.active.keys.map((id) => Entitlement(id: id)).toSet();

      // Why? -> https://www.revenuecat.com/docs/entitlements#entitlements
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

    final purchaseResult = await _purchaseStoreProduct(storeProduct);
    return purchaseResult;
  }

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

    // Try to find the first product where the googleProduct's basePlanId matches the given basePlanId.
    StoreProduct? matchingProduct;

    // Loop through each product in the products list.
    for (final product in products) {
      // Check if the current product's basePlanId matches the given basePlanId.
      if (product.identifier == storeProductId) {
        // If a match is found, assign this product to matchingProduct.
        matchingProduct = product;
        // Break the loop as we found our matching product.
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
          app_logger.AppLogger.error('Valid subscription option not found for product: $productId', tag: _tag);
          return PurchaseResult.failed("Valid subscription option not found for product.");
        }
        return await _purchaseSubscriptionOption(subscriptionOption, productId);
      case ProductCategory.nonSubscription:
        return await _purchaseStoreProduct(storeProduct);
      case null:
        app_logger.AppLogger.error('Unable to determine product category for product: $productId', tag: _tag);
        return PurchaseResult.failed("Unable to determine product category");
    }
  }

  Future<SubscriptionOption?> _fetchGooglePlaySubscriptionOption(
    StoreProduct storeProduct,
    String? basePlanId,
    String? offerId,
  ) async {
    final subscriptionOptions = storeProduct.subscriptionOptions;

    if (subscriptionOptions != null && subscriptionOptions.isNotEmpty) {
      // Concatenate base + offer ID
      final subscriptionOptionId = _buildSubscriptionOptionId(basePlanId, offerId);

      // Find first subscription option that matches the subscription option ID or use the default offer
      SubscriptionOption? subscriptionOption;

      // Search for the subscription option with the matching ID
      for (final option in subscriptionOptions) {
        if (option.id == subscriptionOptionId) {
          subscriptionOption = option;
          break;
        }
      }

      // If no matching subscription option is found, use the default option
      subscriptionOption ??= storeProduct.defaultOption;

      // Return the subscription option
      return subscriptionOption;
    }

    return null;
  }

  Future<PurchaseResult> _purchaseSubscriptionOption(SubscriptionOption subscriptionOption, [String? productId]) async {
    // Define the async perform purchase function
    Future<CustomerInfo> performPurchase() async {
      // Attempt to purchase product
      final CustomerInfo customerInfo = await Purchases.purchaseSubscriptionOption(subscriptionOption);
      return customerInfo;
    }

    final PurchaseResult purchaseResult = await _handleSharedPurchase(performPurchase, productId: productId);
    return purchaseResult;
  }

  Future<PurchaseResult> _purchaseStoreProduct(StoreProduct storeProduct) async {
    // Define the async perform purchase function
    Future<CustomerInfo> performPurchase() async {
      // Attempt to purchase product
      final CustomerInfo customerInfo = await Purchases.purchaseStoreProduct(storeProduct);
      return customerInfo;
    }

    final PurchaseResult purchaseResult = await _handleSharedPurchase(
      performPurchase,
      productId: storeProduct.identifier,
    );
    return purchaseResult;
  }

  // MARK: Shared purchase
  Future<PurchaseResult> _handleSharedPurchase(
    Future<CustomerInfo> Function() performPurchase, {
    String? productId,
  }) async {
    try {
      // Perform the purchase using the function provided
      final CustomerInfo customerInfo = await performPurchase();

      // Handle the results
      if (customerInfo.hasActiveEntitlementOrSubscription()) {
        app_logger.AppLogger.info('Purchase successful for product: ${productId ?? "unknown"}', tag: _tag);
        // Notify callback about successful purchase
        if (productId != null) {
          await _onPurchaseCompleted(productId);
        }
        return PurchaseResult.purchased;
      } else {
        app_logger.AppLogger.error(
          'Purchase completed but no active subscriptions found for product: ${productId ?? "unknown"}',
          tag: _tag,
        );
        return PurchaseResult.failed("No active subscriptions found.");
      }
    } on PlatformException catch (e, stackTrace) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.paymentPendingError) {
        app_logger.AppLogger.info('Purchase pending for product: ${productId ?? "unknown"}', tag: _tag);
        return PurchaseResult.pending;
      } else if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        app_logger.AppLogger.info('Purchase cancelled for product: ${productId ?? "unknown"}', tag: _tag);
        return PurchaseResult.cancelled;
      } else {
        app_logger.AppLogger.error(
          'Purchase failed for product: ${productId ?? "unknown"}',
          tag: _tag,
          error: e,
          stackTrace: stackTrace,
        );
        return PurchaseResult.failed(e.message ?? "Purchase failed in RCPurchaseController");
      }
    } catch (e, stackTrace) {
      app_logger.AppLogger.error(
        'Unexpected error during purchase for product: ${productId ?? "unknown"}',
        tag: _tag,
        error: e,
        stackTrace: stackTrace,
      );
      return PurchaseResult.failed("Unexpected error during purchase");
    }
  }

  // MARK: Handle Restores

  /// Makes a restore with RevenueCat and returns `.restored`, unless an error is thrown.
  /// This gets called when someone tries to restore purchases on one of your paywalls.
  @override
  Future<RestorationResult> restorePurchases() async {
    app_logger.AppLogger.info('Starting purchase restoration', tag: _tag);
    try {
      await Purchases.restorePurchases();
      app_logger.AppLogger.info('Purchase restoration completed successfully', tag: _tag);
      return RestorationResult.restored;
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
}

// MARK: Helpers

String _buildSubscriptionOptionId(String? basePlanId, String? offerId) {
  String result = '';

  if (basePlanId != null) {
    result += basePlanId;
  }

  if (offerId != null) {
    if (basePlanId != null) {
      result += ':';
    }
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
    final combinedProducts = [...subscriptionProducts, ...nonSubscriptionProducts];
    return combinedProducts;
  }
}
