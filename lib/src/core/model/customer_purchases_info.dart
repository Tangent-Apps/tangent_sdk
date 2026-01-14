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

  final String? managementURL;

  /// When this customer was first seen by RevenueCat
  final DateTime? firstSeen;

  /// All product IDs ever purchased by this customer
  final Set<String> allPurchasedProductIds;

  /// All non-subscription purchases (consumables, one-time purchases)
  final List<NonSubscriptionTransaction> nonSubscriptionTransactions;

  const CustomerPurchasesInfo({
    required this.hasActiveSubscription,
    this.originalPurchaseDate,
    this.latestExpirationDate,
    this.purchases = const [],
    required this.originalAppUserId,
    required this.managementURL,
    this.firstSeen,
    this.allPurchasedProductIds = const {},
    this.nonSubscriptionTransactions = const [],
  });

  @override
  String toString() {
    final purchasesStr = purchases.isEmpty ? '[]' : '[\n    ${purchases.map((p) => p.toString()).join(',\n    ')}\n  ]';
    final nonSubStr =
        nonSubscriptionTransactions.isEmpty ? '[]' : '[\n    ${nonSubscriptionTransactions.map((t) => t.toString()).join(',\n    ')}\n  ]';
    return 'CustomerPurchasesInfo(\n'
        '  hasActiveSubscription: $hasActiveSubscription,\n'
        '  originalPurchaseDate: $originalPurchaseDate,\n'
        '  latestExpirationDate: $latestExpirationDate,\n'
        '  purchases: $purchasesStr,\n'
        '  originalAppUserId: $originalAppUserId,\n'
        '  managementURL: $managementURL,\n'
        '  firstSeen: $firstSeen,\n'
        '  allPurchasedProductIds: $allPurchasedProductIds,\n'
        '  nonSubscriptionTransactions: $nonSubStr\n'
        ')';
  }
}

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

  /// The identifier for this entitlement
  final String? entitlementId;

  CustomerPurchaseInfo({
    required this.productId,
    this.originalPurchaseDate,
    this.latestPurchaseDate,
    this.expirationDate,
    this.entitlementId,
    required this.isActive,
    required this.isSandbox,
    required this.willRenew,
  });

  @override
  String toString() {
    return 'CustomerPurchaseInfo(productId: $productId, originalPurchaseDate: $originalPurchaseDate, latestPurchaseDate: $latestPurchaseDate, expirationDate: $expirationDate, isActive: $isActive, isSandbox: $isSandbox, willRenew: $willRenew)';
  }
}

/// Represents a non-subscription purchase (consumable, one-time)
class NonSubscriptionTransaction {
  /// The unique transaction identifier
  final String transactionId;

  /// The product identifier
  final String productId;

  /// When this purchase was made
  final DateTime purchaseDate;

  const NonSubscriptionTransaction({
    required this.transactionId,
    required this.productId,
    required this.purchaseDate,
  });

  @override
  String toString() {
    return 'NonSubscriptionTransaction(transactionId: $transactionId, productId: $productId, purchaseDate: $purchaseDate)';
  }
}
