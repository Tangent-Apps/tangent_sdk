import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:tangent_sdk/src/core/service/analytics_service.dart';
import 'package:tangent_sdk/src/core/utils/app_logger.dart';

import '../core/exceptions/tangent_sdk_exception.dart';
import '../core/types/result.dart';

class MixpanelAnalyticsService implements AnalyticsService {
  final String token;
  Mixpanel? _mixpanel;

  MixpanelAnalyticsService(this.token);

  @override
  Future<Result<void>> initialize() async {
    return resultOfAsync(() async {
      _mixpanel = await Mixpanel.init(token, trackAutomaticEvents: true);
      _mixpanel?.setLoggingEnabled(kDebugMode);
      if (_mixpanel == null) {
        throw ServiceOperationException('Failed to initialize Mixpanel', 'Mixpanel instance is null');
      }
    });
  }

  @override
  Future<Result<void>> logFailureEvent({
    required String eventName,
    required String failureReason,
    Map<String, Object>? properties,
  }) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }
    return _sendEventToServer(
      eventName: eventName,
      properties: {'failure_reason': failureReason, if (properties != null) ...properties},
    );
  }

  @override
  Future<Result<void>> logEvent(String eventName, {Map<String, Object>? properties}) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }
    return _sendEventToServer(eventName: eventName, properties: properties);
  }

  Future<Result<void>> _sendEventToServer({required String eventName, Map<String, Object>? properties}) async {
    return resultOfAsync(() async {
      AppLogger.info('sending event to mixPanel: $eventName');
      await _mixpanel!.track(
        eventName,
        properties: {if (properties != null) ...properties, 'tangent_sdk_version': '0.0.14'},
      );
      AppLogger.info('Successfully event sent to mixPanel: $eventName');
    });
  }

  @override
  Future<Result<void>> logSubscriptionEvent({
    required String eventToken,
    required double price,
    required String currency,
    required String subscriptionId,
    required String? eventName,
    Map<String, String>? context,
  }) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }
    final properties = <String, Object>{
      'event_token': eventToken,
      'price': price,
      'currency': currency,
      'subscription_id': subscriptionId,
    };

    // Add purchase context if provided
    if (context != null) {
      properties.addAll(context);
    }

    return _sendEventToServer(
      eventName: eventName ?? "purchase",
      properties: properties,
    );
  }
}
