import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_config.dart';
import 'package:adjust_sdk/adjust_event.dart';
import 'package:flutter/foundation.dart';
import 'package:tangent_sdk/tangent_sdk.dart';

@immutable
class AdjustAnalyticsService implements AnalyticsService {
  final String appToken;
  final TangentEnvironment environment;

  const AdjustAnalyticsService(this.appToken, this.environment);

  @override
  Future<Result<void>> initialize() async {
    final adjustEnvironment =
        environment == TangentEnvironment.production ? AdjustEnvironment.production : AdjustEnvironment.sandbox;

    final config = AdjustConfig(appToken, adjustEnvironment);

    if (environment == TangentEnvironment.sandbox) {
      config.logLevel = AdjustLogLevel.verbose;
    }

    Adjust.initSdk(config);
    return const Success(null);
  }

  @override
  Future<Result<void>> logEvent(String event, {Map<String, dynamic>? properties}) async {
    final adjustEvent = AdjustEvent(event);

    if (properties != null) {
      properties.forEach((key, value) {
        if (value is String) {
          adjustEvent.addCallbackParameter(key, value);
        } else if (value is num) {
          adjustEvent.addCallbackParameter(key, value.toString());
        }
      });
    }

    // Add campaign tracking parameters
    await _addCampaignParameters(adjustEvent);

    Adjust.trackEvent(adjustEvent);
    return const Success(null);
  }

  /// Track subscription events with revenue and subscription details
  @override
  Future<Result<void>> logSubscriptionEvent({
    required String eventToken,
    required double price,
    required String currency,
    required String subscriptionId,
    required String? eventName,
    Map<String, String>? context,
  }) async {
    final event = AdjustEvent(eventToken);

    // Add revenue info
    event.setRevenue(price, currency);

    // Add subscription details
    event.addCallbackParameter('subscription_id', subscriptionId);
    event.addCallbackParameter('currency', currency);
    event.addCallbackParameter('price', price.toString());
    event.addCallbackParameter('eventName', eventName ?? "successful_purchase");
    event.addCallbackParameter('tangent_sdk_version', '0.0.14');

    // Add purchase context if provided
    if (context != null) {
      context.forEach((key, value) {
        event.addCallbackParameter(key, value);
      });
    }

    // Add campaign tracking parameters
    await _addCampaignParameters(event);

    Adjust.trackEvent(event);
    return const Success(null);
  }

  /// Add campaign parameters to event
  Future<void> _addCampaignParameters(AdjustEvent event) async {
    try {
      final attribution = await Adjust.getAttribution();
      event.addCallbackParameter('campaign', attribution.campaign ?? 'organic');
      event.addCallbackParameter('network', attribution.network ?? 'none');
      event.addCallbackParameter('adgroup', attribution.adgroup ?? 'none');
      event.addCallbackParameter('creative', attribution.creative ?? 'none');
      event.addCallbackParameter('click_label', attribution.clickLabel ?? 'none');
    } catch (e) {
      debugPrint('Failed to add campaign parameters: $e');
    }
  }

  @override
  Future<Result<void>> logFailureEvent({
    required String eventName,
    required String failureReason,
    Map<String, Object>? properties,
  }) {
    return resultOfAsync(() async {});
  }
}
