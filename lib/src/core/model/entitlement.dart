class Entitlement {
  /// The unique identifier for this entitlement
  final String identifier;

  /// The product identifier associated with this entitlement
  final String productIdentifier;

  /// Whether this entitlement is currently active
  final bool isActive;

  /// When this entitlement was first unlocked
  final DateTime? originalPurchaseDate;

  /// When this entitlement was last renewed or purchased
  final DateTime? latestPurchaseDate;

  /// When this entitlement will expire (null for lifetime entitlements)
  final DateTime? expirationDate;

  /// Whether the subscription will auto-renew
  final bool willRenew;

  /// Whether this entitlement is from a sandbox environment
  final bool isSandbox;

  /// When a billing issue was detected (e.g. failed payment during grace/retry period)
  final DateTime? billingIssueDetectedAt;

  const Entitlement({
    required this.identifier,
    required this.productIdentifier,
    required this.isActive,
    this.originalPurchaseDate,
    this.latestPurchaseDate,
    this.expirationDate,
    required this.willRenew,
    required this.isSandbox,
    this.billingIssueDetectedAt,
  });

  @override
  String toString() {
    return 'Entitlement(\n'
        '  identifier: $identifier,\n'
        '  productIdentifier: $productIdentifier,\n'
        '  isActive: $isActive,\n'
        '  originalPurchaseDate: $originalPurchaseDate,\n'
        '  latestPurchaseDate: $latestPurchaseDate,\n'
        '  expirationDate: $expirationDate,\n'
        '  willRenew: $willRenew,\n'
        '  isSandbox: $isSandbox,\n'
        '  billingIssueDetectedAt: $billingIssueDetectedAt\n'
        ')';
  }

  /// Creates a copy of this entitlement with optionally modified fields
  Entitlement copyWith({
    String? identifier,
    String? productIdentifier,
    bool? isActive,
    DateTime? originalPurchaseDate,
    DateTime? latestPurchaseDate,
    DateTime? expirationDate,
    bool? willRenew,
    bool? isSandbox,
    DateTime? billingIssueDetectedAt,
  }) {
    return Entitlement(
      identifier: identifier ?? this.identifier,
      productIdentifier: productIdentifier ?? this.productIdentifier,
      isActive: isActive ?? this.isActive,
      originalPurchaseDate: originalPurchaseDate ?? this.originalPurchaseDate,
      latestPurchaseDate: latestPurchaseDate ?? this.latestPurchaseDate,
      expirationDate: expirationDate ?? this.expirationDate,
      willRenew: willRenew ?? this.willRenew,
      isSandbox: isSandbox ?? this.isSandbox,
      billingIssueDetectedAt: billingIssueDetectedAt ?? this.billingIssueDetectedAt,
    );
  }
}
