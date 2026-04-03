// src/tangent_sdk.dart
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:tangent_sdk/src/core/utils/app_logger.dart';
import 'package:tangent_sdk/src/services/iap_purchase_service.dart';
import 'package:tangent_sdk/src/services/superwall_service.dart';
import 'package:tangent_sdk/tangent_sdk.dart';

class TangentSDK {
  static TangentSDK? _instance;
  final TangentConfig _config;
  CrashReportingService? _crashReporting;
  AppCheckService? _appCheck;
  final List<AnalyticsService> _analyticsServices = [];
  IAPPurchaseService? _iapService;
  AppTrackingTransparencyService? _appTrackingTransparency;
  AppReviewService? _appReview;
  PaywallsService? _superwallService;

  TangentSDK._(this._config);

  static TangentSDK get instance {
    if (_instance == null) {
      throw const ServiceNotInitializedException('TangentSDK');
    }
    return _instance!;
  }

  /// Dispose of resources
  void dispose() {
    AppLogger.info('Disposing TangentSDK resources', tag: 'TangentSDK');
    _iapService?.dispose();
  }

  /// Initialize the SDK with the provided configuration and optional Firebase options.
  ///
  /// This method should be called before using any other SDK features.
  ///
  /// [config] The configuration object containing the SDK settings.
  /// [firebaseOptions] Optional Firebase options for initializing Firebase.

  static Future<TangentSDK> initialize({
    required TangentConfig config,
    FirebaseOptions? firebaseOptions,
    bool enableDebugLogging = false,
  }) async {
    if (_instance != null) {
      _instance!.dispose();
      _instance = null;
    }

    // Configure logging
    AppLogger.setDebugMode(enableDebugLogging);

    // Initialize Firebase if options provided
    if (firebaseOptions != null) {
      await Firebase.initializeApp(options: firebaseOptions);
    }

    _instance = TangentSDK._(config);
    await _instance!._initializeServices();

    return _instance!;
  }

  /// Initialize the SDK services.
  Future<void> _initializeServices() async {
    /// Initialize analytics services
    if (_config.enableAnalytics) {
      if (_config.mixpanelToken != null) {
        AppLogger.info('Initializing Mixpanel Analytics Service', tag: 'Analytics');
        final mixpanel = MixpanelAnalyticsService(_config.mixpanelToken!);
        await mixpanel.initialize();
        _analyticsServices.add(mixpanel);
        AppLogger.info('Mixpanel Analytics Service initialized', tag: 'Analytics');
      }

      if (_config.adjustAppToken != null && _config.environment != null) {
        AppLogger.info('Initializing Adjust Analytics Service', tag: 'Analytics');
        final adjust = AdjustAnalyticsService(_config.adjustAppToken!, _config.environment!);
        await adjust.initialize();
        _analyticsServices.add(adjust);
        AppLogger.info('Adjust Analytics Service initialized', tag: 'Analytics');
      } else {
        throw const ServiceNotInitializedException('AdjustAnalyticsService');
      }

      if (_config.automaticTrackSubscription &&
          _config.adjustSubscriptionToken != null &&
          _config.adjustSubscriptionRenewalToken != null &&
          _config.adjustSubscriptionToken!.isNotEmpty &&
          _config.adjustSubscriptionRenewalToken!.isNotEmpty) {
        AppLogger.info('Automatic Tracking Purchase Events is ON', tag: 'Adjust-Subscription');
      } else if (!_config.automaticTrackSubscription) {
        AppLogger.info('Automatic Tracking Purchase automatic tracking is disabled is OFF', tag: 'Adjust-Subscription');
      } else {
        throw const ValidationException(
          'adjustSubscriptionToken & adjustSubscriptionRenewalToken',
          'Cannot be empty or set automaticTrackSubscription to False',
        );
      }
    }

    // Initialize IAP service
    AppLogger.info('Initializing IAP Purchase Service', tag: 'IAP');
    _iapService = IAPPurchaseService();
    await _iapService!.initialize();
    AppLogger.info('IAP Purchase Service initialized', tag: 'IAP');

    await Future.wait([
      // Initialize Superwall service
      if (_config.enableSuperwall && _config.enableAutoInitSuperwall) initSuperwall(),

      // Initialize crash reporting
      if (_config.enableCrashlytics) _enableCrashlytics(),

      // Initialize app check
      if (_config.enableAppCheck) _enableAppCheck(),

      // Initialize app tracking transparency
      if (_config.enableAppTrackingTransparency) requestTrackingAuthorization(),
    ]);

    // Initialize app review service (utility - always available)
    AppLogger.info('Initializing App Review Service', tag: 'Review');
    _appReview = AppReviewService();
    AppLogger.info('App Review Service initialized', tag: 'Review');
  }

  /// Initialize crash reporting
  Future<void> _enableCrashlytics() async {
    AppLogger.info('Initializing Firebase Crashlytics Service', tag: 'CrashReporting');
    _crashReporting = const FirebaseCrashReportingService();
    await _crashReporting!.initialize();
    AppLogger.info('Firebase Crashlytics Service initialized', tag: 'CrashReporting');
  }

  /// Initialize app check
  Future<void> _enableAppCheck() async {
    AppLogger.info('Initializing Firebase App Check Service', tag: 'AppCheck');
    _appCheck = const FirebaseAppCheckService();
    await _appCheck!.activate();
    AppLogger.info('Firebase App Check Service initialized', tag: 'AppCheck');
  }

  /// Initialize Superwall paywall service for managing subscription paywalls.
  ///
  /// This method can be called in two ways:
  /// 1. **Automatic initialization**: Set `enableAutoInitSuperwall: true` in [TangentConfig]
  ///    and Superwall will be initialized automatically during SDK initialization.
  /// 2. **Manual initialization**: Set `enableAutoInitSuperwall: false` in [TangentConfig]
  ///    and call this method manually when you want to initialize Superwall.
  ///
  /// **Requirements:**
  /// - `enableSuperwall` must be `true` in [TangentConfig]
  /// - iOS API key must be provided via `superwallIOSApiKey` in [TangentConfig]
  /// - Android API key is optional (can be empty string)
  ///
  /// [userId] Optional user ID to identify the user with Superwall.
  Future<void> initSuperwall({String? userId}) async {
    if (!_config.enableSuperwall) {
      AppLogger.info('Superwall is disabled in config', tag: superwallTag);
      return;
    }

    if (_config.superwallIOSApiKey != null) {
      AppLogger.info('Initializing Superwall Service', tag: superwallTag);
      _superwallService ??= SuperwallService(
        iOSApiKey: _config.superwallIOSApiKey!,
        androidApiKey: _config.superwallAndroidApiKey ?? "",
      );

      await _superwallService!.initialize();

      if (userId != null) {
        await _superwallService!.identifyUser(userId);
      }

      AppLogger.info('Superwall Service initialized', tag: superwallTag);
    } else {
      AppLogger.error('Superwall enabled but API keys not configured', tag: superwallTag);
    }
  }

  /// Record an error to the crash reporting service.
  Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    bool fatal = false,
    Map<String, String>? customKeys,
  }) async {
    await _crashReporting?.recordError(exception, stackTrace, fatal: fatal, customKeys: customKeys);
  }

  /// Log a message to the crash reporting service
  Future<void> log(String message) async => _crashReporting?.log(message);

  // Analytics Methods
  /// Track events with specific properties (specifically for Mixpanel)
  Future<void> trackEvent(String event, {Map<String, Object>? properties}) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.logEvent(event, properties: properties);
        if (result.isFailure) {
          AppLogger.error('Failed to send event to Mixpanel: ${result.error}', tag: 'Analytics');
        }
      }
    }
  }

  /// Track failure events with specific failure reason (specifically for Mixpanel)
  Future<void> trackFailureEvent({
    required String eventName,
    required String failureReason,
    Map<String, Object>? properties,
  }) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.logFailureEvent(
          eventName: eventName,
          failureReason: failureReason,
          properties: properties,
        );
        if (result.isFailure) {
          AppLogger.error('Failed to send failure event to Mixpanel: ${result.error}', tag: 'Analytics');
        }
      }
    }
  }

  /// Track subscription events with revenue tracking (specifically for Adjust)
  Future<void> trackSubscription({
    required String eventToken,
    required double price,
    required String currency,
    required String subscriptionId,
    required String? eventName,
    Map<String, String>? context,
  }) async {
    AppLogger.info(
      'Automatic Tracking Purchase Events is ${_config.automaticTrackSubscription} logSubscriptionEvent',
      tag: 'Adjust-Subscription',
    );
    if (_config.automaticTrackSubscription) {
      for (final analytics in _analyticsServices) {
        await analytics.logSubscriptionEvent(
          eventToken: eventToken,
          price: price,
          currency: currency,
          subscriptionId: subscriptionId,
          eventName: eventName,
          context: context,
        );
      }
    } else {
      AppLogger.info('Automatic Tracking Purchase Events is OFF', tag: 'Adjust-Subscription');
    }
  }

  //
  // MARK: - Mixpanel People API Methods

  /// Identify a user in Mixpanel with their unique ID
  /// This should be called when a user logs in or when you want to associate events with a specific user
  Future<void> identifyUser(String userId) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.identify(userId);
        if (result.isFailure) {
          AppLogger.error('Failed to identify user in Mixpanel: ${result.error}', tag: 'Mixpanel-People');
        }
      }
    }
  }

  /// Set user properties in Mixpanel People
  /// Example: setMixpanelUserProperties({'name': 'John Doe', 'email': 'john@example.com', 'plan': 'premium'})
  Future<void> setMixpanelUserProperties(Map<String, dynamic> properties) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.setUserProperties(properties);
        if (result.isFailure) {
          AppLogger.error('Failed to set user properties in Mixpanel: ${result.error}', tag: 'Mixpanel-People');
        }
      }
    }
  }

  /// Set user properties in Mixpanel People only once (won't overwrite existing values)
  /// Useful for properties like signup date, referral source, etc.
  Future<void> setMixpanelUserPropertiesOnce(Map<String, dynamic> properties) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.setUserPropertiesOnce(properties);
        if (result.isFailure) {
          AppLogger.error('Failed to set user properties once in Mixpanel: ${result.error}', tag: 'Mixpanel-People');
        }
      }
    }
  }

  /// Increment a numeric user property in Mixpanel People
  /// Example: incrementMixpanelUserProperty('login_count') or incrementMixpanelUserProperty('credits', 10)
  Future<void> incrementMixpanelUserProperty(String property, [double value = 1]) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.incrementUserProperty(property, value);
        if (result.isFailure) {
          AppLogger.error('Failed to increment user property in Mixpanel: ${result.error}', tag: 'Mixpanel-People');
        }
      }
    }
  }

  /// Append a value to a list property in Mixpanel People
  /// Example: appendToMixpanelUserProperty('favorite_genres', 'Action')
  Future<void> appendToMixpanelUserProperty(String property, dynamic value) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.appendToUserProperty(property, value);
        if (result.isFailure) {
          AppLogger.error('Failed to append to user property in Mixpanel: ${result.error}', tag: 'Mixpanel-People');
        }
      }
    }
  }

  /// Union values with a list property in Mixpanel People (only adds if not already present)
  /// Example: unionMixpanelUserProperty('tags', ['premium', 'early_adopter'])
  Future<void> unionMixpanelUserProperty(String property, List<dynamic> values) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.unionUserProperty(property, values);
        if (result.isFailure) {
          AppLogger.error('Failed to union user property in Mixpanel: ${result.error}', tag: 'Mixpanel-People');
        }
      }
    }
  }

  /// Remove a user property from Mixpanel People
  Future<void> unsetMixpanelUserProperty(String property) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.unsetUserProperty(property);
        if (result.isFailure) {
          AppLogger.error('Failed to unset user property in Mixpanel: ${result.error}', tag: 'Mixpanel-People');
        }
      }
    }
  }

  /// Delete the user profile from Mixpanel People
  /// This should be called when a user requests account deletion
  Future<void> deleteMixpanelUser() async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.deleteUser();
        if (result.isFailure) {
          AppLogger.error('Failed to delete user in Mixpanel: ${result.error}', tag: 'Mixpanel-People');
        }
      }
    }
  }

  /// Reset Mixpanel (clears distinct_id and starts fresh)
  /// This should be called when a user logs out
  Future<void> resetMixpanel() async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.reset();
        if (result.isFailure) {
          AppLogger.error('Failed to reset Mixpanel: ${result.error}', tag: 'Mixpanel-People');
        }
      }
    }
  }

  /// Sync subscription status to Mixpanel People
  /// Sets `has_active_subscription` as a user profile property
  Future<void> syncSubscriptionToMixpanel() async {
    if (!_config.enableMixpanelSubscriptionSync || _config.mixpanelToken == null) return;

    final statusResult = await _superwallService?.getSubscriptionStatus();
    if (statusResult == null) {
      AppLogger.error('Superwall service not initialized', tag: 'Mixpanel-Subscription-Sync');
      return;
    }

    statusResult.when(
      success: (isActive) async {
        await setMixpanelUserProperties({'has_active_subscription': isActive});
        AppLogger.info('Successfully synced subscription status to Mixpanel', tag: 'Mixpanel-Subscription-Sync');
      },
      failure: (error) {
        AppLogger.error('Failed to sync subscription to Mixpanel: $error', tag: 'Mixpanel-Subscription-Sync');
      },
    );
  }

  // MARK: - Mixpanel Super Properties Methods

  /// Register super properties that will be sent with every Mixpanel event
  /// Super properties are automatically included in all events until explicitly cleared
  /// Example: registerMixpanelSuperProperties({'app_version': '1.2.3', 'platform': 'iOS'})
  Future<void> registerMixpanelSuperProperties(Map<String, dynamic> properties) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.registerSuperProperties(properties);
        if (result.isFailure) {
          AppLogger.error('Failed to register super properties in Mixpanel: ${result.error}', tag: 'Mixpanel-Super');
        }
      }
    }
  }

  /// Register super properties only once (won't overwrite existing values)
  /// Useful for properties that should never change, like signup date or initial referrer
  /// Example: registerMixpanelSuperPropertiesOnce({'signup_date': '2025-01-01', 'initial_referrer': 'google'})
  Future<void> registerMixpanelSuperPropertiesOnce(Map<String, dynamic> properties) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.registerSuperPropertiesOnce(properties);
        if (result.isFailure) {
          AppLogger.error(
            'Failed to register super properties once in Mixpanel: ${result.error}',
            tag: 'Mixpanel-Super',
          );
        }
      }
    }
  }

  /// Remove a single super property from Mixpanel
  /// Example: unregisterMixpanelSuperProperty('temporary_flag')
  Future<void> unregisterMixpanelSuperProperty(String property) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.unregisterSuperProperty(property);
        if (result.isFailure) {
          AppLogger.error('Failed to unregister super property in Mixpanel: ${result.error}', tag: 'Mixpanel-Super');
        }
      }
    }
  }

  /// Clear all super properties from Mixpanel
  /// This removes all super properties that were previously registered
  Future<void> clearMixpanelSuperProperties() async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.clearSuperProperties();
        if (result.isFailure) {
          AppLogger.error('Failed to clear super properties in Mixpanel: ${result.error}', tag: 'Mixpanel-Super');
        }
      }
    }
  }

  /// Get current super properties from Mixpanel
  /// Returns a Map of all currently registered super properties
  Future<Map<String, dynamic>> getMixpanelSuperProperties() async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        final result = await analytics.getSuperProperties();
        if (result.isSuccess) {
          return result.data;
        } else {
          AppLogger.error('Failed to get super properties from Mixpanel: ${result.error}', tag: 'Mixpanel-Super');
        }
      }
    }
    return {};
  }

  // MARK: - Purchase Methods (via in_app_purchase)

  /// Get products from the store
  Future<Result<List<Product>>> getProducts(List<String> productIds) async {
    return await _iapService?.getProducts(productIds) ?? const Success([]);
  }

  /// Make a purchase
  /// Returns a [Result] of [Product]
  /// Automatically tracks subscription events to Adjust and syncs to Superwall + Mixpanel on success
  Future<Result<Product>> purchaseProduct(
    Product product, {
    String? eventToken,
    String? eventName,
    Map<String, String>? context,
  }) async {
    final productResult = await _iapService?.purchaseProduct(product);

    if (productResult == null) {
      throw const ServiceNotInitializedException('IAPPurchaseService');
    }

    if (productResult.isSuccess) {
      final purchasedProduct = productResult.data;

      // Track subscription event to Adjust
      _silentTrackSubscriptionEvent(
        product: purchasedProduct,
        eventToken: eventToken,
        eventName: eventName,
        context: context,
      );

      // Sync subscription status to Superwall
      await _syncSubscriptionToSuperwall();

      // Sync to Mixpanel after successful purchase
      if (_config.enableMixpanelSubscriptionSync && _config.mixpanelToken != null) {
        await syncSubscriptionToMixpanel();
      }

      return Success(purchasedProduct);
    } else {
      return Failure(productResult.error);
    }
  }

  /// Check if the user has an active subscription (via Superwall)
  Future<Result<bool>> checkActiveSubscription() async {
    return await _superwallService?.getSubscriptionStatus() ?? const Success(false);
  }

  /// Restore purchases
  /// Returns a [Result] of [bool] indicating success
  Future<Result<bool>> restorePurchases() async {
    final result = await _iapService?.restorePurchases() ?? const Success(false);

    // Sync to Mixpanel after successful restore
    if (result.isSuccess && _config.enableMixpanelSubscriptionSync && _config.mixpanelToken != null) {
      AppLogger.info('Purchases restored, syncing to Mixpanel', tag: 'IAP-Restore');
      await syncSubscriptionToMixpanel();
    }

    return result;
  }

  /// Stream of subscription status changes (via Superwall)
  Stream<bool> get subscriptionStatusStream =>
      _superwallService?.subscriptionStatusStream ?? const Stream.empty();

  /// Sync subscription status to Superwall by setting active entitlements
  Future<void> _syncSubscriptionToSuperwall() async {
    if (_superwallService == null) return;
    await _superwallService!.setSubscriptionStatus(activeEntitlementIds: ['Pro']);
  }

  /// Fire-and-forget wrapper around [trackSubscription].
  ///
  /// The method purposely swallows any thrown error and logs it, so that failures
  /// in Adjust/Mixpanel tracking never interfere with the purchase flow.
  Future<void> _silentTrackSubscriptionEvent({
    required Product product,
    String? eventToken,
    String? eventName,
    Map<String, String>? context,
  }) async {
    try {
      await trackSubscription(
        eventToken: eventToken ?? _config.adjustSubscriptionToken!,
        price: product.price,
        currency: product.currencyCode,
        subscriptionId: product.id,
        eventName: eventName ?? "subscribe",
        context: context,
      );
    } catch (err) {
      AppLogger.error(err.toString());
    }
  }

  /// App Tracking Transparency Methods
  Future<void> requestTrackingAuthorization() async {
    AppLogger.info('Initializing App Tracking Transparency Service', tag: 'Tracking');
    _appTrackingTransparency ??= AppTrackingTransparencyService();
    await _appTrackingTransparency!.init();
    AppLogger.info('App Tracking Transparency Service initialized', tag: 'Tracking');
  }

  Future<TrackingStatus?> getTrackingStatus() async {
    return await _appTrackingTransparency?.getTrackingStatus();
  }

  Future<String?> getAdvertisingIdentifier() async {
    return await _appTrackingTransparency?.getAdvertisingIdentifier();
  }

  // App Review Methods
  Future<void> requestReview() async {
    await _appReview?.requestReview();
  }

  Future<bool> isReviewAvailable() async {
    return await _appReview?.isAvailable() ?? false;
  }

  Future<void> openStoreListing({String? appStoreId}) async {
    await _appReview?.openStoreListing(appStoreId: appStoreId);
  }

  /// MARK: Superwall/Paywall Methods
  /// Register a placement with Superwall
  Future<Result<void>> superwallRegisterPlacement(
    String placement, {
    Map<String, Object>? params,
    Function? feature,
  }) async {
    AppLogger.debug('Registering Superwall placement: $placement', tag: superwallTag);
    if (_superwallService == null) {
      AppLogger.error('Superwall service not initialized', tag: superwallTag);
      return const Failure(ServiceNotInitializedException(superwallTag));
    }
    final result = await _superwallService!.registerPlacement(placement, params: params, feature: feature);
    result.when(
      success: (_) => AppLogger.info('Successfully registered placement: $placement', tag: superwallTag),
      failure: (error) => AppLogger.error('Failed to register placement: $placement', error: error, tag: superwallTag),
    );
    return result;
  }

  /// Identify user with Superwall
  Future<Result<void>> superwallIdentifySuperwallUser(String userId) async {
    AppLogger.debug('Identifying Superwall user: $userId', tag: superwallTag);
    if (_superwallService == null) {
      AppLogger.error('Superwall service not initialized', tag: superwallTag);
      return const Failure(ServiceNotInitializedException(superwallTag));
    }
    final result = await _superwallService!.identifyUser(userId);
    result.when(
      success: (_) => AppLogger.info('Successfully identified user: $userId', tag: superwallTag),
      failure: (error) => AppLogger.error('Failed to identify user: $userId', error: error, tag: superwallTag),
    );
    return result;
  }

  /// Set user attributes for Superwall
  Future<Result<void>> superwallSetUserAttributes(Map<String, dynamic> attributes) async {
    AppLogger.debug('Setting Superwall user attributes: ${attributes.keys.join(", ")}', tag: superwallTag);
    if (_superwallService == null) {
      AppLogger.error('Superwall service not initialized', tag: superwallTag);
      return const Failure(ServiceNotInitializedException(superwallTag));
    }
    final result = await _superwallService!.setUserAttributes(attributes);
    result.when(
      success: (_) => AppLogger.info('Successfully set user attributes', tag: superwallTag),
      failure: (error) => AppLogger.error('Failed to set user attributes', error: error, tag: superwallTag),
    );
    return result;
  }

  /// Reset Superwall session
  Future<Result<void>> superwallReset() async {
    AppLogger.info('Resetting Superwall session', tag: superwallTag);
    if (_superwallService == null) {
      AppLogger.error('Superwall service not initialized', tag: superwallTag);
      return const Failure(ServiceNotInitializedException(superwallTag));
    }
    final result = await _superwallService!.reset();
    result.when(
      success: (_) => AppLogger.info('Successfully reset Superwall session', tag: superwallTag),
      failure: (error) => AppLogger.error('Failed to reset Superwall session', error: error, tag: superwallTag),
    );
    return result;
  }

  /// Handle deep link with Superwall
  Future<Result<void>> superwallHandleDeepLink(Uri url) async {
    AppLogger.info('Handling Superwall deep link: $url', tag: superwallTag);
    if (_superwallService == null) {
      AppLogger.error('Superwall service not initialized', tag: superwallTag);
      return const Failure(ServiceNotInitializedException(superwallTag));
    }
    final result = await _superwallService!.handleDeepLink(url);
    result.when(
      success: (_) => AppLogger.info('Successfully handled deep link: $url', tag: superwallTag),
      failure: (error) => AppLogger.error('Failed to handle deep link: $url', error: error, tag: superwallTag),
    );
    return result;
  }

  /// Dismiss currently presented paywall
  Future<Result<void>> dismissPaywall() async {
    AppLogger.info('Dismissing Superwall paywall', tag: superwallTag);
    if (_superwallService == null) {
      AppLogger.error('Superwall service not initialized', tag: superwallTag);
      return const Failure(ServiceNotInitializedException(superwallTag));
    }
    final result = await _superwallService!.dismissPaywall();
    result.when(
      success: (_) => AppLogger.info('Successfully dismissed paywall', tag: superwallTag),
      failure: (error) => AppLogger.error('Failed to dismiss paywall', error: error, tag: superwallTag),
    );
    return result;
  }

  /// Set subscription status for Superwall
  Future<Result<void>> superwallSetSubscriptionStatus({List<String> activeEntitlementIds = const []}) async {
    AppLogger.info(
      'Setting Superwall subscription status with entitlements: ${activeEntitlementIds.join(", ")}',
      tag: superwallTag,
    );
    if (_superwallService == null) {
      AppLogger.error('Superwall service not initialized', tag: superwallTag);
      return const Failure(ServiceNotInitializedException(superwallTag));
    }
    final result = await _superwallService!.setSubscriptionStatus(activeEntitlementIds: activeEntitlementIds);
    result.when(
      success: (_) => AppLogger.info('Successfully set subscription status', tag: superwallTag),
      failure: (error) => AppLogger.error('Failed to set subscription status', error: error, tag: superwallTag),
    );
    return result;
  }

  /// Refresh subscription status
  Future<Result<void>> refreshSuperwallSubscriptionStatus() async {
    AppLogger.info('Refreshing Superwall subscription status', tag: superwallTag);
    if (_superwallService == null) {
      AppLogger.error('Superwall service not initialized', tag: superwallTag);
      return const Failure(ServiceNotInitializedException(superwallTag));
    }
    final result = await _superwallService!.refreshSubscriptionStatus();
    result.when(
      success: (_) => AppLogger.info('Successfully refreshed subscription status', tag: superwallTag),
      failure: (error) => AppLogger.error('Failed to refresh subscription status', error: error, tag: superwallTag),
    );
    return result;
  }
}
