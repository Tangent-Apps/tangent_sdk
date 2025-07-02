import 'package:firebase_core/firebase_core.dart';
import 'package:tangent_sdk/src/core/exceptions/tangent_sdk_exception.dart';
import 'package:tangent_sdk/src/core/service/purchases_service.dart';
import 'package:tangent_sdk/src/services/adjust_analytics_service.dart';
import 'package:tangent_sdk/tangent_sdk.dart';

class TangentSDK {
  static TangentSDK? _instance;
  final TangentConfig _config;
  CrashReportingService? _crashReporting;
  AppCheckService? _appCheck;
  List<AnalyticsService> _analyticsServices = [];
  PurchasesService? _revenueService;
  AppTrackingTransparencyService? _appTrackingTransparency;
  AppReviewService? _appReview;

  TangentSDK._(this._config);

  static TangentSDK get instance {
    if (_instance == null) {
      throw ServiceNotInitializedException('TangentSDK');
    }
    return _instance!;
  }

  ///Initialize the SDK with the provided configuration and optional Firebase options.
  ///
  ///This method should be called before using any other SDK features.
  ///
  ///[config] The configuration object containing the SDK settings.
  ///[firebaseOptions] Optional Firebase options for initializing Firebase.

  static Future<TangentSDK> initialize({required TangentConfig config, FirebaseOptions? firebaseOptions}) async {
    if (_instance != null) {
      return _instance!;
    }

    // Initialize Firebase if options provided
    if (firebaseOptions != null) {
      await Firebase.initializeApp(options: firebaseOptions);
    }

    _instance = TangentSDK._(config);
    await _instance!._initializeServices();

    return _instance!;
  }

  ///Initialize the SDK services.
  ///
  ///This method should be called after initializing the SDK.
  ///
  ///[config] The configuration object containing the SDK settings.
  ///[firebaseOptions] Optional Firebase options for initializing Firebase.
  Future<void> _initializeServices() async {
    // Initialize crash reporting
    if (_config.enableCrashlytics) {
      log('🔥 Initializing Firebase Crashlytics Service');
      _crashReporting = const FirebaseCrashReportingService();
      await _crashReporting!.initialize();
      log('✅ Firebase Crashlytics Service initialized');
    }

    // Initialize app check
    if (_config.enableAppCheck) {
      log('🔥 Initializing Firebase App Check Service');
      _appCheck = const FirebaseAppCheckService();
      await _appCheck!.activate();
      log('✅ Firebase App Check Service initialized');
    }

    // Initialize analytics services
    if (_config.enableAnalytics) {
      if (_config.mixpanelToken != null) {
        log('🔥 Initializing Mixpanel Analytics Service');
        final mixpanel = MixpanelAnalyticsService(_config.mixpanelToken!);
        await mixpanel.initialize();
        _analyticsServices.add(mixpanel);
        log('✅ Mixpanel Analytics Service initialized');
      }

      if (_config.adjustAppToken != null && _config.environment != null) {
        log('🔥 Initializing Adjust Analytics Service');
        final adjust = AdjustAnalyticsService(_config.adjustAppToken!, _config.environment!);
        await adjust.initialize();
        _analyticsServices.add(adjust);
        log('✅ Adjust Analytics Service initialized');
      } else {
        throw ServiceNotInitializedException('AdjustAnalyticsService');
      }
    }

    // Initialize purchases service
    if (_config.enableRevenue && _config.revenueCatApiKey != null) {
      log('🔥 Initializing RevenueCat Service');
      _revenueService = RevenueCatService(_config.revenueCatApiKey!);
      await _revenueService!.initialize();
      log('✅ RevenueCat Service initialized');
    }

    // Initialize app tracking transparency
    log('🔥 Initializing App Tracking Transparency Service');
    _appTrackingTransparency = AppTrackingTransparencyService();
    await _appTrackingTransparency!.init();
    log('✅ App Tracking Transparency Service initialized');

    // Initialize app review service (utility - always available)
    log('⭐ Initializing App Review Service');
    _appReview = AppReviewService();
    log('✅ App Review Service initialized');
  }

  Future<void> recordError(dynamic exception, StackTrace? stackTrace, {bool fatal = false, Map<String, String>? customKeys}) async {
    await _crashReporting?.recordError(exception, stackTrace, fatal: fatal, customKeys: customKeys);
  }

  Future<void> log(String message) async {
    await _crashReporting?.log(message);
  }

  // Analytics Methods
  /// Track events with specific properties (specifically for Mixpanel)
  Future<void> trackEvent(String event, {Map<String, Object>? properties}) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        await analytics.logEvent(event, properties: {...properties ?? {}, 'tangent_sdk_version': '0.0.1'});
      }
    }
  }

  /// Track failure events with specific failure reason (specifically for Mixpanel)
  Future<void> trackFailureEvent({required String eventName, required String failureReason, Map<String, Object>? properties}) async {
    for (final analytics in _analyticsServices) {
      if (analytics is MixpanelAnalyticsService) {
        await analytics.logFailureEvent(
          eventName: eventName,
          failureReason: failureReason,
          properties: {...properties ?? {}, 'tangent_sdk_version': '0.0.1'},
        );
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
  }) async {
    for (final analytics in _analyticsServices) {
      await analytics.logSubscriptionEvent(
        eventToken: eventToken,
        price: price,
        currency: currency,
        subscriptionId: subscriptionId,
        eventName: eventName,
      );
    }
  }

  // Revenue Methods
  Future<Result<List<Product>>> getProducts(List<String> productIds) async {
    return await _revenueService?.getProducts(productIds) ?? const Success([]);
  }

  Future<Result<PurchaseResult>> purchaseProduct(String productId) async {
    return await _revenueService?.purchaseProduct(productId) ?? const Success(PurchaseResult.invalid);
  }

  Future<Result<bool>> isProductPurchased(String productId) async {
    final result = await _revenueService?.isProductPurchased(productId) ?? const Success(false);
    return result;
  }

  Future<Result<bool>> checkActiveSubscription() async {
    return await _revenueService?.checkActiveSubscription() ?? const Success(false);
  }

  Future<Result<bool>> checkActiveSubscriptionToEntitlement(String entitlementId) async {
    return await _revenueService?.checkActiveSubscriptionToEntitlement(entitlementId) ?? const Success(false);
  }

  Future<Result<bool>> restorePurchases() async {
    return await _revenueService?.restorePurchases() ?? const Success(false);
  }

  Future<Result<List<Product>>> getOffering(String offeringId) async {
    return await _revenueService?.getOffering(offeringId) ?? const Success([]);
  }

  Future<Result<List<Product>>> getOfferings() async {
    return await _revenueService?.getOfferings() ?? const Success([]);
  }

  Stream<bool> get hasActiveSubscriptionStream => _revenueService?.hasActivePurchasesStream ?? const Stream.empty();

  // App Tracking Transparency Methods
  Future<void> requestTrackingAuthorization() async {
    await _appTrackingTransparency?.init();
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
}
