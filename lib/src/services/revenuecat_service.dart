import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' as service;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:meta/meta.dart';
import 'package:tangent_sdk/src/core/enum/puchase_result_enum.dart';
import 'package:tangent_sdk/src/core/service/purchases_service.dart';
import 'package:tangent_sdk/src/core/types/product.dart';
import 'package:tangent_sdk/src/core/types/purchase.dart';
import 'package:tangent_sdk/src/core/types/result.dart';

import '../core/exceptions/tangent_sdk_exception.dart';

@immutable
class RevenueCatService extends PurchasesService {
  final String apiKey;
  final StreamController<bool> _hasActivePurchaseController = StreamController<bool>.broadcast();

  RevenueCatService(this.apiKey) {
    if (apiKey.trim().isEmpty) {
      throw ValidationException('apiKey', 'Cannot be empty');
    }
  }

  @override
  Future<Result<void>> initialize() async {
    return resultOfAsync(() async {
      await Purchases.setLogLevel(LogLevel.info);
      await Purchases.configure(PurchasesConfiguration(apiKey));
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        if (!_hasActivePurchaseController.isClosed) {
          _hasActivePurchaseController.add(customerInfo.activeSubscriptions.isNotEmpty);
        }
      });
    }).mapErrorAsync((error) => ServiceOperationException('RevenueCat initialization', error.originalError));
  }

  @override
  Future<Result<List<Product>>> getProducts(List<String> productIds) async {
    if (productIds.isEmpty) {
      return Failure(ValidationException('productIds', 'Cannot be empty'));
    }

    return resultOfAsync(() async {
      final productsResult = await Purchases.getProducts(productIds);
      final products = <Product>[];
      for (int i = 0; i < productsResult.length; i++) {
        products.add(
          Product(
            id: productsResult[i].identifier,
            title: productsResult[i].title,
            description: productsResult[i].description,
            price: productsResult[i].price,
            priceString: productsResult[i].priceString,
            storeProduct: productsResult[i],
            currencyCode: productsResult[i].currencyCode,
            introductoryPrice: productsResult[i].introductoryPrice?.priceString,
          ),
        );
      }

      return products;
    }).mapErrorAsync((error) => PurchaseException('getProducts', originalError: error.originalError));
  }

  @override
  Future<Result<PurchaseResult>> purchaseProduct(String productId) async {
    if (productId.trim().isEmpty) {
      return Failure(ValidationException('productId', 'Cannot be empty'));
    }

    return resultOfAsync(() async {
      try {
        final targetPackage = await Purchases.getProducts([productId]);

        if (targetPackage.isEmpty) {
          return PurchaseResult.invalid;
        }

        final customerInfo = await Purchases.purchaseStoreProduct(targetPackage.first);
        _hasActivePurchaseController.add(customerInfo.activeSubscriptions.isNotEmpty);
        return PurchaseResult.success;
      } on service.PlatformException catch (e) {
        final errorCode = PurchasesErrorHelper.getErrorCode(e);
        switch (errorCode) {
          case PurchasesErrorCode.purchaseCancelledError:
            return PurchaseResult.userCancelled;
          case PurchasesErrorCode.purchaseNotAllowedError:
            return PurchaseResult.notAllowed;
          case PurchasesErrorCode.purchaseInvalidError:
            return PurchaseResult.invalid;
          default:
            return PurchaseResult.storeError;
        }
      }
    }).mapErrorAsync((error) => PurchaseException('purchaseProduct', originalError: error.originalError));
  }

  @override
  Future<Result<bool>> restorePurchases() async {
    return resultOfAsync(() async {
      final CustomerInfo result = await Purchases.restorePurchases();
      return result.activeSubscriptions.isNotEmpty;
    }).mapErrorAsync((error) => PurchaseException('restorePurchases', originalError: error.originalError));
  }

  @override
  Future<Result<bool>> isProductPurchased(String productId) async {
    return resultOfAsync(() async {
      final CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.activeSubscriptions.isNotEmpty;
    }).mapErrorAsync((error) => PurchaseException('isProductPurchased', originalError: error.originalError));
  }

  @override
  Stream<bool> get hasActivePurchasesStream => _hasActivePurchaseController.stream;

  void dispose() {
    if (!_hasActivePurchaseController.isClosed) {
      _hasActivePurchaseController.close();
    }
  }

  @override
  Future<Result<bool>> checkActiveSubscription() async {
    return resultOfAsync(() async {
      final CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.activeSubscriptions.isNotEmpty;
    }).mapErrorAsync((error) => PurchaseException('checkActiveSubscription', originalError: error.originalError));
  }

  @override
  Future<Result<bool>> checkActiveSubscriptionToEntitlement(String entitlementId) async {
    if (entitlementId.trim().isEmpty) {
      return Failure(ValidationException('entitlementId', 'Cannot be empty'));
    }

    return resultOfAsync(() async {
      final CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(entitlementId);
    }).mapErrorAsync((error) => PurchaseException('checkActiveSubscriptionToEntitlement', originalError: error.originalError));
  }

  @override
  Future<Result<List<Product>>> getOffering(String offeringId) async {
    if (offeringId.trim().isEmpty) {
      return Failure(ValidationException('offeringId', 'Cannot be empty'));
    }

    return resultOfAsync(() async {
      final offerings = await Purchases.getOfferings();
      final products = <Product>[];
      final offering = offerings.getOffering(offeringId);
      if (offering != null) {
        for (final package in offering.availablePackages) {
          products.add(
            Product(
              id: package.storeProduct.identifier,
              title: package.storeProduct.title,
              description: package.storeProduct.description,
              price: package.storeProduct.price,
              priceString: package.storeProduct.priceString,
              storeProduct: package.storeProduct,
              currencyCode: package.storeProduct.currencyCode,
              introductoryPrice: package.storeProduct.introductoryPrice?.priceString,
            ),
          );
        }
      }
      return products;
    }).mapErrorAsync((error) => PurchaseException('getOffering', originalError: error.originalError));
  }

  @override
  Future<Result<List<Product>>> getOfferings() async {
    return resultOfAsync(() async {
      final offerings = await Purchases.getOfferings();
      final products = <Product>[];

      for (final offering in offerings.all.values) {
        for (final package in offering.availablePackages) {
          products.add(
            Product(
              id: package.storeProduct.identifier,
              title: package.storeProduct.title,
              description: package.storeProduct.description,
              price: package.storeProduct.price,
              priceString: package.storeProduct.priceString,
              storeProduct: package.storeProduct,
              currencyCode: package.storeProduct.currencyCode,
              introductoryPrice: package.storeProduct.introductoryPrice?.priceString,
            ),
          );
        }
      }
      return products;
    }).mapErrorAsync((error) => PurchaseException('getOfferings', originalError: error.originalError));
  }
}
