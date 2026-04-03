import 'package:flutter/services.dart';
import 'package:tangent_sdk/src/core/model/billing_status.dart';
import 'package:tangent_sdk/src/core/utils/app_logger.dart';

class BillingIssueService {
  static const _channel = MethodChannel('com.tangent_sdk/billing_issue');

  /// Check billing issue status via native StoreKit 2 / Play Billing
  Future<BillingStatus> checkBillingIssue() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('checkBillingIssue');
      if (result == null) {
        return const BillingStatus(state: BillingState.normal);
      }
      return BillingStatus(
        state: BillingState.values.byName(result['state'] as String),
        billingIssueDetectedAt: result['billingIssueDetectedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(result['billingIssueDetectedAt'] as int)
            : null,
        gracePeriodExpiresAt: result['gracePeriodExpiresAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(result['gracePeriodExpiresAt'] as int)
            : null,
        managementURL: result['managementURL'] as String?,
      );
    } on PlatformException catch (e) {
      AppLogger.error('Failed to check billing issue', error: e, tag: 'BillingIssue');
      return const BillingStatus(state: BillingState.normal);
    }
  }
}
