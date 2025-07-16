import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import 'package:tangent_sdk/src/core/model/customer_purchases_info.dart';
import 'package:tangent_sdk/src/core/model/product.dart';
import 'package:tangent_sdk/src/core/model/purchase.dart';
import 'package:tangent_sdk/src/core/enum/puchase_result_enum.dart';
import '../types/result.dart';

@immutable
abstract class PurchasesService {
  const PurchasesService();

  Future<Result<void>> initialize();

  Future<Result<List<Product>>> getProducts(List<String> productIds);

  Future<Result<PurchaseResult>> purchaseProductById(String productId);

  Future<Result<PurchaseResult>> purchaseProduct(dynamic product);


  Future<Result<CustomerPurchasesInfo>> restorePurchases();

  Future<Result<bool>> checkActiveSubscription();

  Future<Result<List<Product>>> getOffering(String offerId);

  Future<Result<List<Product>>> getOfferings();

  Future<Result<bool>> checkActiveSubscriptionToEntitlement(String entitlementId);

  Future<Result<CustomerPurchasesInfo>> getCustomerPurchasesInfo();

  Stream<CustomerPurchasesInfo> get customerPurchasesInfoStream;
}
