import 'package:meta/meta.dart';
import '../types/result.dart';

@immutable
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
  });

  Future<Result<void>> logFailureEvent({required String eventName, required String failureReason, Map<String, Object>? properties});
}
