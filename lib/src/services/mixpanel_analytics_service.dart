// src/services/mixpanel_analytics_service.dart
import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:tangent_sdk/src/core/service/analytics_service.dart';
import 'package:tangent_sdk/src/core/utils/app_logger.dart';

import 'package:tangent_sdk/src/core/exceptions/tangent_sdk_exception.dart';
import 'package:tangent_sdk/src/core/model/constants.dart';
import 'package:tangent_sdk/src/core/types/result.dart';

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
        throw const ServiceOperationException('Failed to initialize Mixpanel', 'Mixpanel instance is null');
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
        properties: {if (properties != null) ...properties, 'tangent_sdk_version': tangentSdkVersion},
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

    return _sendEventToServer(eventName: eventName ?? "purchase", properties: properties);
  }

  // MARK: - Mixpanel People API Methods

  /// Identify a user with a unique ID
  /// This sets the distinct_id for all future events and people property updates
  Future<Result<void>> identify(String userId) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Identifying user: $userId', tag: 'Mixpanel-People');
      _mixpanel!.identify(userId);
      AppLogger.info('User identified successfully: $userId', tag: 'Mixpanel-People');
    });
  }

  /// Set user properties
  /// These properties will be set on the user profile in Mixpanel People
  Future<Result<void>> setUserProperties(Map<String, dynamic> properties) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Setting user properties: ${properties.keys.join(', ')}', tag: 'Mixpanel-People');

      // Set all properties
      for (final entry in properties.entries) {
        _mixpanel!.getPeople().set(entry.key, entry.value);
      }

      AppLogger.info('User properties set successfully', tag: 'Mixpanel-People');
    });
  }

  /// Set user properties only once (won't overwrite existing values)
  Future<Result<void>> setUserPropertiesOnce(Map<String, dynamic> properties) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Setting user properties once: ${properties.keys.join(', ')}', tag: 'Mixpanel-People');

      for (final entry in properties.entries) {
        _mixpanel!.getPeople().setOnce(entry.key, entry.value);
      }

      AppLogger.info('User properties set once successfully', tag: 'Mixpanel-People');
    });
  }

  /// Increment a numeric user property
  Future<Result<void>> incrementUserProperty(String property, [double value = 1]) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Incrementing user property: $property by $value', tag: 'Mixpanel-People');
      _mixpanel!.getPeople().increment(property, value);
      AppLogger.info('User property incremented successfully', tag: 'Mixpanel-People');
    });
  }

  /// Append a value to a list property
  Future<Result<void>> appendToUserProperty(String property, dynamic value) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Appending to user property: $property', tag: 'Mixpanel-People');
      _mixpanel!.getPeople().append(property, value);
      AppLogger.info('Value appended to user property successfully', tag: 'Mixpanel-People');
    });
  }

  /// Union a value with a list property (only adds if not already present)
  Future<Result<void>> unionUserProperty(String property, List<dynamic> values) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Union user property: $property', tag: 'Mixpanel-People');
      _mixpanel!.getPeople().union(property, values);
      AppLogger.info('Values unioned with user property successfully', tag: 'Mixpanel-People');
    });
  }

  /// Remove a user property
  Future<Result<void>> unsetUserProperty(String property) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Unsetting user property: $property', tag: 'Mixpanel-People');
      _mixpanel!.getPeople().unset(property);
      AppLogger.info('User property unset successfully', tag: 'Mixpanel-People');
    });
  }

  /// Delete the user profile from Mixpanel People
  Future<Result<void>> deleteUser() async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Deleting user profile', tag: 'Mixpanel-People');
      _mixpanel!.getPeople().deleteUser();
      AppLogger.info('User profile deleted successfully', tag: 'Mixpanel-People');
    });
  }

  /// Reset the Mixpanel instance (clears distinct_id and starts fresh)
  Future<Result<void>> reset() async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Resetting Mixpanel instance', tag: 'Mixpanel-People');
      _mixpanel!.reset();
      AppLogger.info('Mixpanel instance reset successfully', tag: 'Mixpanel-People');
    });
  }

  // MARK: - Mixpanel Super Properties Methods

  /// Register super properties that will be sent with every event
  /// Super properties are properties that are automatically included in all events
  /// They persist across app sessions until explicitly cleared
  Future<Result<void>> registerSuperProperties(Map<String, dynamic> properties) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Registering super properties: ${properties.keys.join(', ')}', tag: 'Mixpanel-Super');
      _mixpanel!.registerSuperProperties(properties);
      AppLogger.info('Super properties registered successfully', tag: 'Mixpanel-Super');
    });
  }

  /// Register super properties only once (won't overwrite existing values)
  /// Useful for properties that should never change, like signup date or initial referrer
  Future<Result<void>> registerSuperPropertiesOnce(Map<String, dynamic> properties) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Registering super properties once: ${properties.keys.join(', ')}', tag: 'Mixpanel-Super');
      _mixpanel!.registerSuperPropertiesOnce(properties);
      AppLogger.info('Super properties registered once successfully', tag: 'Mixpanel-Super');
    });
  }

  /// Remove a single super property
  Future<Result<void>> unregisterSuperProperty(String property) async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Unregistering super property: $property', tag: 'Mixpanel-Super');
      _mixpanel!.unregisterSuperProperty(property);
      AppLogger.info('Super property unregistered successfully', tag: 'Mixpanel-Super');
    });
  }

  /// Clear all super properties
  Future<Result<void>> clearSuperProperties() async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Clearing all super properties', tag: 'Mixpanel-Super');
      _mixpanel!.clearSuperProperties();
      AppLogger.info('All super properties cleared successfully', tag: 'Mixpanel-Super');
    });
  }

  /// Get current super properties
  Future<Result<Map<String, dynamic>>> getSuperProperties() async {
    if (_mixpanel == null) {
      return const Failure(ServiceNotInitializedException('MixpanelAnalyticsService'));
    }

    return resultOfAsync(() async {
      AppLogger.info('Getting super properties', tag: 'Mixpanel-Super');
      final properties = await _mixpanel!.getSuperProperties();
      final typedProperties = Map<String, dynamic>.from(properties ?? {});
      AppLogger.info('Retrieved ${typedProperties.length} super properties', tag: 'Mixpanel-Super');
      return typedProperties;
    });
  }
}
