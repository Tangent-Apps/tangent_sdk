import 'package:meta/meta.dart';

@immutable
class CustomerPurchasesInfo {
  /// true if the user has at least one active subscription
  final bool hasActiveSubscription;

  /// Whether any active purchase has a billing issue (failed payment in grace/retry period)
  final bool hasBillingIssue;

  /// The earliest billing issue detection date among active purchases, if any
  final DateTime? billingIssueDetectedAt;

  /// URL to manage subscriptions (App Store / Google Play)
  final String? managementURL;

  const CustomerPurchasesInfo({
    required this.hasActiveSubscription,
    this.hasBillingIssue = false,
    this.billingIssueDetectedAt,
    this.managementURL,
  });

  @override
  String toString() {
    return 'CustomerPurchasesInfo('
        'hasActiveSubscription: $hasActiveSubscription, '
        'hasBillingIssue: $hasBillingIssue, '
        'billingIssueDetectedAt: $billingIssueDetectedAt, '
        'managementURL: $managementURL'
        ')';
  }
}
