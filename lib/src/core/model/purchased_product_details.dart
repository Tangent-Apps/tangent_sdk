import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:meta/meta.dart';

/// Details of a store transaction delivered through the purchase stream.
///
/// Carries everything an app needs to grant content exactly once:
/// [purchaseID] for idempotent granting, [status] to distinguish fresh
/// purchases from restores, and [verificationData] for optional
/// server-side receipt validation before granting.
@immutable
class PurchasedProductDetails {
  /// The store product identifier.
  final String productID;

  /// The unique transaction identifier from the store.
  /// Use this to deduplicate grants — the store redelivers transactions
  /// that were never completed (e.g. after a crash mid-delivery).
  final String? purchaseID;

  /// Transaction timestamp as provided by the store, if available.
  final String? transactionDate;

  /// Whether this transaction is a fresh purchase or a restore.
  /// Apps should not grant consumables for [PurchaseStatus.restored].
  final PurchaseStatus status;

  /// Store receipt data (StoreKit receipt / Play purchase token) for
  /// optional server-side validation inside the delivery handler.
  final String verificationData;

  /// The store this verification data comes from (e.g. 'app_store', 'google_play').
  final String verificationSource;

  const PurchasedProductDetails({
    required this.productID,
    required this.status,
    required this.verificationData,
    required this.verificationSource,
    this.purchaseID,
    this.transactionDate,
  });

  @override
  String toString() =>
      'PurchasedProductDetails(productID: $productID, purchaseID: $purchaseID, status: $status)';
}

/// Awaited by the SDK before the transaction is completed with the store.
///
/// Return `true` once the content has been granted (coins credited,
/// entitlement acknowledged). Returning `false` or throwing leaves the
/// transaction unfinished, so the store redelivers it on next app launch.
typedef PurchaseDeliveryHandler = Future<bool> Function(PurchasedProductDetails details);
