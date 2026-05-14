import 'package:meta/meta.dart';

/// Model containing computed subscription details derived from entitlements.
///
/// This model abstracts away the Superwall entitlement internals and
/// exposes simple boolean flags for the host app to consume.
@immutable
class SubscriptionDetailsModel {
  /// Whether the user's active subscription originated from a web store (Stripe).
  final bool isWebSubscriber;

  /// Whether the user has ever used a free trial offer (across all entitlements).
  final bool hasUsedTrial;

  const SubscriptionDetailsModel({
    this.isWebSubscriber = false,
    this.hasUsedTrial = false,
  });

  @override
  String toString() {
    return 'SubscriptionDetailsModel('
        'isWebSubscriber: $isWebSubscriber, '
        'hasUsedTrial: $hasUsedTrial'
        ')';
  }
}
