import 'package:meta/meta.dart';

enum BillingState {
  /// Active and paid
  normal,

  /// Payment failed, user still has access (grace period)
  inGracePeriod,

  /// Payment failed, grace expired, store retrying charges
  inBillingRetryPeriod,

  /// Subscription expired
  expired,

  /// Revoked (refund, family sharing removed)
  revoked,
}

@immutable
class BillingStatus {
  final BillingState state;
  final DateTime? billingIssueDetectedAt;
  final DateTime? gracePeriodExpiresAt;
  final String? managementURL;

  const BillingStatus({
    required this.state,
    this.billingIssueDetectedAt,
    this.gracePeriodExpiresAt,
    this.managementURL,
  });

  bool get hasBillingIssue =>
      state == BillingState.inGracePeriod ||
      state == BillingState.inBillingRetryPeriod;

  @override
  String toString() {
    return 'BillingStatus('
        'state: $state, '
        'hasBillingIssue: $hasBillingIssue, '
        'billingIssueDetectedAt: $billingIssueDetectedAt, '
        'gracePeriodExpiresAt: $gracePeriodExpiresAt, '
        'managementURL: $managementURL'
        ')';
  }
}
