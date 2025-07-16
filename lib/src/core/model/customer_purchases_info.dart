class CustomerPurchasesInfo {
  /// true if the user has at least one active subscription entitlement
  final bool hasActiveSubscription;

  /// The date when the user first unlocked any entitlement
  final DateTime? originalPurchaseDate;

  /// The latest expiration date among all active subscriptions
  final DateTime? latestExpirationDate;

  /// Detailed list of all purchases (subscriptions and non-subscriptions)
  final List<CustomerPurchaseInfo> purchases;

  /// The original App User ID (e.g. RevenueCat's appUserId)
  final String originalAppUserId;

  CustomerPurchasesInfo({
    required this.hasActiveSubscription,
    this.originalPurchaseDate,
    this.latestExpirationDate,
    this.purchases = const [],
    required this.originalAppUserId,
  });}


/// Detailed info about a single purchase or entitlement
class CustomerPurchaseInfo {
  /// The identifier for this product or entitlement
  final String productId;

  /// When this entitlement/product was first unlocked/purchased
  final DateTime? originalPurchaseDate;

  /// When it was last purchased or renewed
  final DateTime? latestPurchaseDate;

  /// Expiration date for subscriptions, or null for non-expiring products
  final DateTime? expirationDate;

  /// True if the entitlement/product is currently active
  final bool isActive;

  /// True if this purchase came from a sandbox environment
  final bool isSandbox;

  /// True if a subscription is set to auto-renew
  final bool willRenew;

  CustomerPurchaseInfo({
    required this.productId,
    this.originalPurchaseDate,
    this.latestPurchaseDate,
    this.expirationDate,
    required this.isActive,
    required this.isSandbox,
    required this.willRenew,
  });
}
