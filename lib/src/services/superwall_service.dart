import 'dart:io';

import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:tangent_sdk/src/core/exceptions/tangent_sdk_exception.dart';
import 'package:tangent_sdk/src/core/service/paywalls_service.dart';
import 'package:tangent_sdk/src/core/types/result.dart';
import 'package:tangent_sdk/src/core/utils/app_logger.dart';
import 'package:tangent_sdk/src/services/rc_purchase_controller.dart';

const superwallTag = "Superwall💸";

class SuperwallService extends PaywallsService {
  final String iOSApiKey;
  final String androidApiKey;
  final String revenueCarUserId;
  final SuperwallPurchaseCallback onSubscriptionPurchaseCompleted;
  final SuperwallPurchaseCallback onConsumablePurchaseCompleted;

  bool _isInitialized = false;

  SuperwallService({
    required this.revenueCarUserId,
    required this.iOSApiKey,
    required this.androidApiKey,
    required this.onSubscriptionPurchaseCompleted,
    required this.onConsumablePurchaseCompleted,
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

      // 1) Configure
      // Set a callback to be notified when a purchase is completed through Superwall
      final RCPurchaseController purchaseController = RCPurchaseController(
        onSubscriptionPurchaseCompleted,
        onConsumablePurchaseCompleted,
      );
      Superwall.configure(
        apiKey,
        purchaseController: purchaseController,
        completion: () {
          AppLogger.info('Superwall configuration completed', tag: superwallTag);
        },
      );
      _isInitialized = true;

      // 2) Identify with the SAME id as RevenueCat
      await identifyUser(revenueCarUserId);
      AppLogger.info('Identify with the SAME id as RevenueCat', tag: superwallTag);

      // 3) Configure And Sync Subscription Status && Get Subscription Status
      await purchaseController.configureAndSyncSubscriptionStatus();
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

      // Register the placement with default parameters
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
      // Convert dynamic values to Object
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
      } else {
        await Superwall.shared.setSubscriptionStatus(SubscriptionStatusInactive());
      }
      AppLogger.info('Subscription status setting not fully implemented', tag: superwallTag);

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
      // Note: refreshSubscriptionStatus is not available in the current SDK version
      // This is a placeholder for future implementation
      AppLogger.info('refreshSubscriptionStatus is not implemented in current SDK version', tag: superwallTag);

      return const Success(null);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to refresh subscription status', error: e, stackTrace: stackTrace, tag: superwallTag);
      return Failure(ServiceOperationException('refresh subscription status', e));
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw const ServiceNotInitializedException('SuperwallService');
    }
  }
}
