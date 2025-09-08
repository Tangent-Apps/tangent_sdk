import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' as service;
import 'package:meta/meta.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tangent_sdk/src/core/helper/customer_purchase_info_helper.dart';
import 'package:tangent_sdk/src/core/helper/purchase_error_helper.dart';
import 'package:tangent_sdk/src/core/model/customer_purchases_info.dart';
import 'package:tangent_sdk/src/core/model/product.dart';
import 'package:tangent_sdk/src/core/service/purchases_service.dart';
import 'package:tangent_sdk/src/core/types/result.dart';

import '../core/exceptions/tangent_sdk_exception.dart';

@immutable
class RevenueCatService extends PurchasesService {
  final String apiKey;
  final StreamController<CustomerPurchasesInfo> _customerPurchasesInfoController =
      StreamController<CustomerPurchasesInfo>.broadcast();

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
        if (!_customerPurchasesInfoController.isClosed) {
          final customerPurchasesInfo = CustomerPurchaseInfoHelper.fromRevenueCat(customerInfo);
          _customerPurchasesInfoController.add(customerPurchasesInfo);
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
    }).mapErrorAsync((error) => PurchaseMethodException('getProducts', originalError: error.originalError));
  }

  @override
  Future<Result<Product>> purchaseProductById(String productId) async {
    if (productId.trim().isEmpty) {
      return Failure(ValidationException('productId', 'Cannot be empty'));
    }

    return resultOfAsync(() async {
      try {
        final targetPackage = await Purchases.getProducts([productId]);

        if (targetPackage.isEmpty) {
          throw PurchaseMethodException('Product not found');
        }

        final storeProduct = targetPackage.first;
        final customerInfo = await Purchases.purchaseStoreProduct(storeProduct);
        final customerPurchasesInfo = CustomerPurchaseInfoHelper.fromRevenueCat(customerInfo);
        _customerPurchasesInfoController.add(customerPurchasesInfo);

        return Product(
          id: storeProduct.identifier,
          title: storeProduct.title,
          description: storeProduct.description,
          price: storeProduct.price,
          priceString: storeProduct.priceString,
          storeProduct: storeProduct,
          currencyCode: storeProduct.currencyCode,
          introductoryPrice: storeProduct.introductoryPrice?.priceString,
        );
      } on service.PlatformException catch (e) {
        final errorCode = PurchasesErrorHelper.getErrorCode(e);
        throw PurchaseErrorHelper.getAppropriateException(errorCode: errorCode, originalError: e);
      }
    }).mapErrorAsync((error) => PurchaseMethodException('purchaseProductById', originalError: error.originalError));
  }

  @override
  Future<Result<CustomerPurchasesInfo>> purchaseProduct(Product product) async {
    try {
      final customerInfo = await Purchases.purchaseStoreProduct(product.storeProduct);
      final customerPurchasesInfo = CustomerPurchaseInfoHelper.fromRevenueCat(customerInfo);
      _customerPurchasesInfoController.add(customerPurchasesInfo);
      return Success(customerPurchasesInfo);
    } on service.PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      return Future.value(Failure(PurchaseErrorHelper.getAppropriateException(errorCode: errorCode, originalError: e)));
    } catch (err) {
      return Future.value(Failure(PurchaseMethodException('purchaseProduct', originalError: err)));
    }
  }

  @override
  Future<Result<CustomerPurchasesInfo>> restorePurchases() async {
    return resultOfAsync(() async {
      final CustomerInfo result = await Purchases.restorePurchases();
      final customerPurchasesInfo = CustomerPurchaseInfoHelper.fromRevenueCat(result);
      return customerPurchasesInfo;
    }).mapErrorAsync((error) => PurchaseMethodException('restorePurchases', originalError: error.originalError));
  }

  void dispose() {
    if (!_customerPurchasesInfoController.isClosed) {
      _customerPurchasesInfoController.close();
    }
  }

  @override
  Future<Result<bool>> checkActiveSubscription() async {
    return resultOfAsync(() async {
      final CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.activeSubscriptions.isNotEmpty;
    }).mapErrorAsync((error) => PurchaseMethodException('checkActiveSubscription', originalError: error.originalError));
  }

  @override
  Future<Result<bool>> checkActiveSubscriptionToEntitlement(String entitlementId) async {
    if (entitlementId.trim().isEmpty) {
      return Failure(ValidationException('entitlementId', 'Cannot be empty'));
    }

    return resultOfAsync(() async {
      final CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(entitlementId);
    }).mapErrorAsync(
      (error) => PurchaseMethodException('checkActiveSubscriptionToEntitlement', originalError: error.originalError),
    );
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
    }).mapErrorAsync((error) => PurchaseMethodException('getOffering', originalError: error.originalError));
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
    }).mapErrorAsync((error) => PurchaseMethodException('getOfferings', originalError: error.originalError));
  }

  @override
  Stream<CustomerPurchasesInfo> get customerPurchasesInfoStream => _customerPurchasesInfoController.stream;

  @override
  Future<Result<CustomerPurchasesInfo>> getCustomerPurchasesInfo() async {
    return resultOfAsync(
      () async {
        final CustomerInfo customerInfo = await Purchases.getCustomerInfo();
        final customerPurchasesInfo = CustomerPurchaseInfoHelper.fromRevenueCat(customerInfo);
        return customerPurchasesInfo;
      },
    ).mapErrorAsync((error) => PurchaseMethodException('getCustomerPurchasesInfo', originalError: error.originalError));
  }

  @override
  Future<Result<String?>> getManagementUrl() async {
    return resultOfAsync(() async {
      final CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.managementURL;
    }).mapErrorAsync((error) => PurchaseMethodException('getManagementUrl', originalError: error.originalError));
  }

  @override
  Future<Result<void>> logIn(String appUserId) async {
    if (appUserId.trim().isEmpty) {
      return Failure(ValidationException('appUserId', 'Cannot be empty'));
    }

    return resultOfAsync(() async {
      final LogInResult logInResult = await Purchases.logIn(appUserId);
      final customerPurchasesInfo = CustomerPurchaseInfoHelper.fromRevenueCat(logInResult.customerInfo);
      _customerPurchasesInfoController.add(customerPurchasesInfo);
    }).mapErrorAsync((error) => PurchaseMethodException('logIn', originalError: error.originalError));
  }
}
