import 'dart:async';
import 'dart:io';

import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:tangent_sdk/src/core/exceptions/tangent_sdk_exception.dart';
import 'package:tangent_sdk/src/core/service/paywalls_service.dart';
import 'package:tangent_sdk/src/core/types/result.dart';
import 'package:tangent_sdk/src/core/utils/app_logger.dart';

const superwallTag = "Superwall💸";

class SuperwallService extends PaywallsService implements SuperwallDelegate {
  final String iOSApiKey;
  final String androidApiKey;

  bool _isInitialized = false;

  final StreamController<bool> _subscriptionStatusController = StreamController<bool>.broadcast();
  final StreamController<void> _willRedeemLinkController = StreamController<void>.broadcast();
  final StreamController<RedemptionResult> _didRedeemLinkController = StreamController<RedemptionResult>.broadcast();

  Stream<void> get willRedeemLinkStream => _willRedeemLinkController.stream;
  Stream<RedemptionResult> get didRedeemLinkStream => _didRedeemLinkController.stream;

  SuperwallService({
    required this.iOSApiKey,
    required this.androidApiKey,
  });

  @override
  Future<Result<void>> initialize() async {
    try {
      if (_isInitialized) {
        AppLogger.info('Superwall already initialized', tag: superwallTag);
        return const Success(null);
      }

      final apiKey = Platform.isIOS ? iOSApiKey : androidApiKey;

      if (apiKey.isEmpty) {
        return Failure(
          ValidationException('Superwall API Key', 'API key for ${Platform.isIOS ? 'iOS' : 'Android'} is empty'),
        );
      }

      AppLogger.info('Initializing Superwall with ${Platform.isIOS ? 'iOS' : 'Android'} API key', tag: superwallTag);

      // Configure Superwall in native mode (no PurchaseController)
      Superwall.configure(
        apiKey,
        completion: () {
          AppLogger.info('Superwall configuration completed', tag: superwallTag);
        },
      );
      _isInitialized = true;

      // Set delegate for redemption and lifecycle callbacks
      Superwall.shared.setDelegate(this);

      // Log initial subscription status
      Superwall.shared.getSubscriptionStatus().then((status) {
        AppLogger.info('Superwall subscription status: $status', tag: superwallTag);
      });

      AppLogger.info('Superwall initialized successfully', tag: superwallTag);
      return const Success(null);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize Superwall', error: e, stackTrace: stackTrace, tag: superwallTag);
      return Failure(ServiceOperationException('Superwall initialization', e));
    }
  }

  @override
  Future<Result<void>> registerPlacement(String placement, {Map<String, Object>? params, Function? feature}) async {
    try {
      _ensureInitialized();

      AppLogger.debug('Registering placement: $placement', tag: superwallTag);

      await Superwall.shared.registerPlacement(placement, params: params, feature: feature);

      return const Success(null);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to register placement: $placement', error: e, stackTrace: stackTrace, tag: superwallTag);
      return Failure(ServiceOperationException('register placement: $placement', e));
    }
  }

  @override
  Future<Result<void>> identifyUser(String userId) async {
    try {
      _ensureInitialized();

      AppLogger.info('Identifying user: $userId', tag: superwallTag);
      await Superwall.shared.identify(userId);

      return const Success(null);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to identify user', error: e, stackTrace: stackTrace, tag: superwallTag);
      return Failure(ServiceOperationException('identify user', e));
    }
  }

  @override
  Future<Result<void>> setUserAttributes(Map<String, dynamic> attributes) async {
    try {
      _ensureInitialized();

      AppLogger.debug('Setting user attributes', tag: superwallTag);
      final Map<String, Object> convertedAttributes = {};
      attributes.forEach((key, value) {
        if (value != null) {
          convertedAttributes[key] = value as Object;
        }
      });
      await Superwall.shared.setUserAttributes(convertedAttributes);

      return const Success(null);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set user attributes', error: e, stackTrace: stackTrace, tag: superwallTag);
      return Failure(ServiceOperationException('set user attributes', e));
    }
  }

  @override
  Future<Result<void>> reset() async {
    try {
      _ensureInitialized();

      AppLogger.info('Resetting Superwall', tag: superwallTag);
      await Superwall.shared.reset();

      return const Success(null);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to reset Superwall', error: e, stackTrace: stackTrace, tag: superwallTag);
      return Failure(ServiceOperationException('reset Superwall', e));
    }
  }

  @override
  Future<Result<void>> handleDeepLink(Uri url) async {
    try {
      _ensureInitialized();

      AppLogger.info('Handling deep link: $url', tag: superwallTag);
      final handled = await Superwall.shared.handleDeepLink(url);

      if (handled) {
        AppLogger.info('Deep link handled by Superwall', tag: superwallTag);
      } else {
        AppLogger.info('Deep link not handled by Superwall', tag: superwallTag);
      }

      return const Success(null);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to handle deep link', error: e, stackTrace: stackTrace, tag: superwallTag);
      return Failure(ServiceOperationException('handle deep link', e));
    }
  }

  @override
  Future<Result<void>> preloadPaywalls() async {
    try {
      _ensureInitialized();

      AppLogger.info('Preloading paywalls', tag: superwallTag);
      await Superwall.shared.preloadAllPaywalls();
      AppLogger.info('Successfully preloaded paywalls', tag: superwallTag);

      return const Success(null);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to preload paywalls', error: e, stackTrace: stackTrace, tag: superwallTag);
      return Failure(ServiceOperationException('preload paywalls', e));
    }
  }

  @override
  Future<Result<void>> dismissPaywall() async {
    try {
      _ensureInitialized();

      AppLogger.debug('Dismissing paywall', tag: superwallTag);
      await Superwall.shared.dismiss();
      AppLogger.info('Successfully dismissed paywall', tag: superwallTag);

      return const Success(null);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to dismiss paywall', error: e, stackTrace: stackTrace, tag: superwallTag);
      return Failure(ServiceOperationException('dismiss paywall', e));
    }
  }

  @override
  Future<Result<void>> setSubscriptionStatus({List<String> activeEntitlementIds = const []}) async {
    try {
      _ensureInitialized();

      AppLogger.info('Setting subscription status', tag: superwallTag);
      if (activeEntitlementIds.isNotEmpty) {
        final entitlements = activeEntitlementIds.map((id) => Entitlement(id: id)).toSet();
        await Superwall.shared.setSubscriptionStatus(SubscriptionStatusActive(entitlements: entitlements));
        _subscriptionStatusController.add(true);
      } else {
        await Superwall.shared.setSubscriptionStatus(SubscriptionStatusInactive());
        _subscriptionStatusController.add(false);
      }
      AppLogger.info('Subscription status set successfully', tag: superwallTag);

      return const Success(null);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set subscription status', error: e, stackTrace: stackTrace, tag: superwallTag);
      return Failure(ServiceOperationException('set subscription status', e));
    }
  }

  @override
  Future<Result<void>> refreshSubscriptionStatus() async {
    try {
      _ensureInitialized();

      AppLogger.info('Refreshing subscription status', tag: superwallTag);
      AppLogger.info('refreshSubscriptionStatus is not implemented in current SDK version', tag: superwallTag);

      return const Success(null);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to refresh subscription status', error: e, stackTrace: stackTrace, tag: superwallTag);
      return Failure(ServiceOperationException('refresh subscription status', e));
    }
  }

  @override
  Future<Result<bool>> getSubscriptionStatus() async {
    try {
      _ensureInitialized();

      final status = await Superwall.shared.getSubscriptionStatus();
      final isActive = status is SubscriptionStatusActive;
      AppLogger.info('Subscription status: $isActive', tag: superwallTag);
      return Success(isActive);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get subscription status', error: e, stackTrace: stackTrace, tag: superwallTag);
      return Failure(ServiceOperationException('get subscription status', e));
    }
  }

  @override
  Stream<bool> get subscriptionStatusStream => _subscriptionStatusController.stream;

  Future<void> setAdjustId(String adjustId) async {
    _ensureInitialized();
    await Superwall.shared.setIntegrationAttribute(
      IntegrationAttribute.adjustId,
      adjustId,
    );
  }

  // --- SuperwallDelegate methods ---

  @override
  void willRedeemLink() {
    AppLogger.info('Will redeem web checkout link', tag: superwallTag);
    _willRedeemLinkController.add(null);
  }

  @override
  void didRedeemLink(RedemptionResult result) {
    AppLogger.info('Did redeem web checkout link: $result', tag: superwallTag);
    _didRedeemLinkController.add(result);
  }

  @override
  void subscriptionStatusDidChange(SubscriptionStatus newValue) {
    final isActive = newValue is SubscriptionStatusActive;
    AppLogger.info('Subscription status changed: $isActive', tag: superwallTag);
    _subscriptionStatusController.add(isActive);
  }

  @override
  void handleSuperwallEvent(SuperwallEventInfo eventInfo) {}

  @override
  void handleCustomPaywallAction(String name) {}

  @override
  void willDismissPaywall(PaywallInfo paywallInfo) {}

  @override
  void willPresentPaywall(PaywallInfo paywallInfo) {}

  @override
  void didDismissPaywall(PaywallInfo paywallInfo) {}

  @override
  void didPresentPaywall(PaywallInfo paywallInfo) {}

  @override
  void paywallWillOpenURL(Uri url) {}

  @override
  void paywallWillOpenDeepLink(Uri url) {}

  @override
  void handleLog(String level, String scope, String? message, Map<dynamic, dynamic>? info, String? error) {}

  @override
  void handleSuperwallDeepLink(Uri fullURL, List<String> pathComponents, Map<String, String> queryParameters) {}

  @override
  void customerInfoDidChange(CustomerInfo from, CustomerInfo to) {}

  @override
  void userAttributesDidChange(Map<String, Object> newAttributes) {}

  void dispose() {
    _subscriptionStatusController.close();
    _willRedeemLinkController.close();
    _didRedeemLinkController.close();
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw const ServiceNotInitializedException('SuperwallService');
    }
  }
}
