import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import 'package:tangent_sdk/src/core/types/product.dart';
import 'package:tangent_sdk/src/core/types/purchase.dart';
import 'package:tangent_sdk/src/core/enum/puchase_result_enum.dart';
import '../types/result.dart';

@immutable
abstract class PurchasesService {
  const PurchasesService();

  Future<Result<void>> initialize();

  Future<Result<List<Product>>> getProducts(List<String> productIds);

  Future<Result<PurchaseResult>> purchaseProduct(String productId);

  Future<Result<bool>> restorePurchases();

  Future<Result<bool>> isProductPurchased(String productId);

  Future<Result<List<Product>>> getOffering(String offerId);

  Future<Result<List<Product>>> getOfferings();

  Future<Result<bool>> checkActiveSubscriptionToEntitlement(String entitlementId);

  Future<Result<bool>> checkActiveSubscription();

  Stream<bool> get hasActivePurchasesStream;
}
