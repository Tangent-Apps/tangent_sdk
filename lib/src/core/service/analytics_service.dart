import 'package:tangent_sdk/src/core/types/result.dart';

abstract class AnalyticsService {
  const AnalyticsService();

  Future<Result<void>> initialize();

  Future<Result<void>> logEvent(String event, {Map<String, Object>? properties});

  Future<Result<void>> logSubscriptionEvent({
    required String eventToken,
    required double price,
    required String currency,
    required String subscriptionId,
    required String? eventName,
    Map<String, String>? context,
  });

  Future<Result<void>> logFailureEvent({required String eventName, required String failureReason, Map<String, Object>? properties});
}
