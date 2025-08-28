import 'package:purchases_flutter/models/customer_info_wrapper.dart';
import 'package:tangent_sdk/src/core/model/customer_purchases_info.dart';

class CustomerPurchaseInfoHelper {
  static CustomerPurchasesInfo fromRevenueCat(CustomerInfo customerInfo) {
    final subs = <CustomerPurchaseInfo>[];
    customerInfo.entitlements.all.forEach((id, info) {
      subs.add(
        CustomerPurchaseInfo(
          productId: info.productIdentifier,
          originalPurchaseDate: DateTime.tryParse(info.originalPurchaseDate),
          latestPurchaseDate: DateTime.tryParse(info.latestPurchaseDate),
          expirationDate: info.expirationDate != null ? DateTime.tryParse(info.expirationDate!) : null,
          isActive: info.isActive,
          isSandbox: info.isSandbox,
          willRenew: info.willRenew,
          entitlementId: id,
        ),
      );
    });

    return CustomerPurchasesInfo(
      hasActiveSubscription: customerInfo.activeSubscriptions.isNotEmpty,
      originalPurchaseDate:
          customerInfo.originalPurchaseDate != null ? DateTime.tryParse(customerInfo.originalPurchaseDate!) : null,
      latestExpirationDate:
          customerInfo.latestExpirationDate != null ? DateTime.tryParse(customerInfo.latestExpirationDate!) : null,
      purchases: subs,
      originalAppUserId: customerInfo.originalAppUserId,
      managementURL: customerInfo.managementURL,
    );
  }
}
