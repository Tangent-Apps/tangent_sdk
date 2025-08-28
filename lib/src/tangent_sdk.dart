import 'package:firebase_core/firebase_core.dart';
import 'package:tangent_sdk/src/core/service/purchases_service.dart';
import 'package:tangent_sdk/src/core/utils/app_logger.dart';
import 'package:tangent_sdk/src/services/adjust_analytics_service.dart';
import 'package:tangent_sdk/tangent_sdk.dart';

class TangentSDK {
  static TangentSDK? _instance;
  final TangentConfig _config;
  CrashReportingService? _crashReporting;
  AppCheckService? _appCheck;
  final List<AnalyticsService> _analyticsServices = [];
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
      return _instance!;
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
  ///
  /// This method should be called after initializing the SDK.
  ///
  /// [config] The configuration object containing the SDK settings.
  /// [firebaseOptions] Optional Firebase options for initializing Firebase.
  Future<void> _initializeServices() async {
    // Initialize crash reporting
    if (_config.enableCrashlytics) {
      AppLogger.info('Initializing Firebase Crashlytics Service', tag: 'CrashReporting');
      _crashReporting = const FirebaseCrashReportingService();
      await _crashReporting!.initialize();
      AppLogger.info('Firebase Crashlytics Service initialized', tag: 'CrashReporting');
    }

    // Initialize app check
    if (_config.enableAppCheck) {
      AppLogger.info('Initializing Firebase App Check Service', tag: 'AppCheck');
      _appCheck = const FirebaseAppCheckService();
      await _appCheck!.activate();
      AppLogger.info('Firebase App Check Service initialized', tag: 'AppCheck');
    }

    // Initialize analytics services
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
        throw ServiceNotInitializedException('AdjustAnalyticsService');
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
        throw ValidationException(
          'adjustSubscriptionToken & adjustSubscriptionRenewalToken',
          'Cannot be empty or set automaticTrackSubscription to False',
        );
      }
    }

    // Initialize purchases service
    if (_config.enableRevenue && _config.revenueCatApiKey != null) {
      AppLogger.info('Initializing RevenueCat Service', tag: 'Revenue');
      _revenueService = RevenueCatService(_config.revenueCatApiKey!);
      await _revenueService!.initialize();
      AppLogger.info('RevenueCat Service initialized', tag: 'Revenue');
    }

    // Initialize app tracking transparency
    AppLogger.info('Initializing App Tracking Transparency Service', tag: 'Tracking');
    _appTrackingTransparency = AppTrackingTransparencyService();
    await _appTrackingTransparency!.init();
    AppLogger.info('App Tracking Transparency Service initialized', tag: 'Tracking');

    // Initialize app review service (utility - always available)
    AppLogger.info('Initializing App Review Service', tag: 'Review');
    _appReview = AppReviewService();
    AppLogger.info('App Review Service initialized', tag: 'Review');
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
        await analytics.logEvent(event, properties: properties);
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
        await analytics.logFailureEvent(eventName: eventName, failureReason: failureReason, properties: properties);
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
    if (_config.automaticTrackSubscription) {
      for (final analytics in _analyticsServices) {
        await analytics.logSubscriptionEvent(
          eventToken: eventToken,
          price: price,
          currency: currency,
          subscriptionId: subscriptionId,
          eventName: eventName,
        );
      }
    } else {
      AppLogger.info('Automatic Tracking Purchase Events is OFF', tag: 'Adjust-Subscription');
    }
  }

  // Revenue Methods
  Future<Result<List<Product>>> getProducts(List<String> productIds) async {
    return await _revenueService?.getProducts(productIds) ?? const Success([]);
  }

  /// Purchase a product by id
  /// Returns a [Result] of [CustomerPurchasesInfo]
  /// Automatically tracks subscription events
  /// Automatically tracks failure events
  Future<Result<Product>> purchaseProductById(String productId, {String? eventToken, String? eventName}) async {
    // Check if this is a renewal before making the purchase
    final isRenewal = await _checkIsRenewal(productId);
    final productResult = await _revenueService?.purchaseProductById(productId);

    if (productResult == null) {
      throw ServiceNotInitializedException('PurchasesService');
    }

    return productResult.when(
      success: (product) {
        _silentTrackSubscriptionEvent(
          product: product,
          isRenewalEvent: isRenewal,
          eventName: eventName,
          eventToken: eventToken,
        );
        return Success(product);
      },
      failure: (failure) async {
        if (failure is PurchaseException) {
          await trackFailureEvent(
            eventName: 'error_while_making_purchase',
            failureReason: failure.code ?? PurchaseFailureCode.unknown.name,
            properties: {
              'original_error': failure.originalError,
              'product_id': productId,
              'purchase_error_code': failure.code ?? PurchaseFailureCode.unknown.name,
            },
          );
        } else {
          await trackFailureEvent(
            eventName: 'error_while_making_purchase',
            failureReason: failure.message,
            properties: {
              'original_error': failure.originalError,
              'product_id': productId,
              'purchase_error_code': failure.code ?? PurchaseFailureCode.unknown.name,
            },
          );
        }
        return Future.value(Failure(failure));
      },
    );
  }

  /// Make a purchase
  /// Returns a [Result] of [CustomerPurchasesInfo]
  /// Automatically tracks subscription events
  /// Automatically tracks failure events
  Future<Result<CustomerPurchasesInfo>> purchaseProduct(
    Product product, {
    String? eventToken,
    String? eventName,
  }) async {
    // Check if this is a renewal before making the purchase
    final isRenewal = await _checkIsRenewal(product.id);
    final productResult = await _revenueService?.purchaseProduct(product);

    if (productResult == null) {
      throw ServiceNotInitializedException('PurchasesService');
    }
    return productResult.when(
      success: (customerPurchasesInfo) {
        _silentTrackSubscriptionEvent(
          product: product,
          isRenewalEvent: isRenewal,
          eventToken: eventToken,
          eventName: eventName,
        );
        return Success(customerPurchasesInfo);
      },
      failure: (failure) {
        if (failure is PurchaseException) {
          trackFailureEvent(
            eventName: 'error_while_making_purchase',
            failureReason: failure.code ?? PurchaseFailureCode.unknown.name,
            properties: {
              'original_error': failure.originalError,
              'product_id': product.id,
              'product_title': product.title,
              'product_price': product.priceString,
              'product_currency_code': product.currencyCode,
              'purchase_error_code': failure.code ?? PurchaseFailureCode.unknown.name,
            },
          );
        } else {
          trackFailureEvent(
            eventName: 'error_while_making_purchase',
            failureReason: failure.message,
            properties: {
              'original_error': failure.originalError,
              'product_id': product.id,
              'product_title': product.title,
              'product_price': product.priceString,
              'product_currency_code': product.currencyCode,
              'purchase_error_code': failure.code ?? PurchaseFailureCode.unknown.name,
            },
          );
        }
        return Future.value(Failure(failure));
      },
    );
  }

  Future<Result<bool>> checkActiveSubscription() async {
    return await _revenueService?.checkActiveSubscription() ?? const Success(false);
  }

  Future<Result<bool>> checkActiveSubscriptionToEntitlement(String entitlementId) async {
    return await _revenueService?.checkActiveSubscriptionToEntitlement(entitlementId) ?? const Success(false);
  }

  Future<Result<CustomerPurchasesInfo>> restorePurchases() async {
    return await _revenueService?.restorePurchases() ??
        Success(CustomerPurchasesInfo(hasActiveSubscription: false, originalAppUserId: '', purchases: [], managementURL: null));
  }

  Future<Result<List<Product>>> getOffering(String offeringId) async {
    return await _revenueService?.getOffering(offeringId) ?? const Success([]);
  }

  Future<Result<List<Product>>> getOfferings() async {
    return await _revenueService?.getOfferings() ?? const Success([]);
  }

  Stream<CustomerPurchasesInfo> get customerPurchasesInfoStream =>
      _revenueService?.customerPurchasesInfoStream ?? const Stream.empty();

  Future<Result<String?>> getManagementUrl() async {
    return await _revenueService?.getManagementUrl() ?? const Success(null);
  }

  /// Determines if the given `productId` is a renewal purchase based on the
  /// existing purchase history.
  ///
  /// Returns `true` when:
  /// * The customer has already purchased the product, **and**
  /// * The existing purchase contains an `originalPurchaseDate` (i.e. not a trial).
  Future<bool> _checkIsRenewal(String productId) async {
    try {
      final customerInfo = await _revenueService?.getCustomerPurchasesInfo();
      if (customerInfo == null) return false;

      return customerInfo.when(
        success: (info) {
          // Check if user has previously purchased this product
          final existingPurchase = info.purchases.firstWhere(
            (purchase) => purchase.productId == productId,
            orElse: () => CustomerPurchaseInfo(productId: '', isActive: false, isSandbox: false, willRenew: false),
          );

          // It's a renewal if:
          // 1. The product exists in purchase history
          // 2. Has an original purchase date (was purchased before)
          return existingPurchase.productId.isNotEmpty && existingPurchase.originalPurchaseDate != null;
        },
        failure: (_) => false,
      );
    } catch (err) {
      return false;
    }
  }

  /// Fire-and-forget wrapper around [trackSubscription].
  ///
  /// The method purposely swallows any thrown error and logs it, so that failures
  /// in Adjust/Mixpanel tracking never interfere with the purchase flow.
  Future<void> _silentTrackSubscriptionEvent({
    required Product product,
    bool isRenewalEvent = false,
    String? eventToken,
    String? eventName,
  }) async {
    try {
      await trackSubscription(
        eventToken:
            eventToken ?? (isRenewalEvent ? _config.adjustSubscriptionRenewalToken! : _config.adjustSubscriptionToken!),
        price: product.price,
        currency: product.currencyCode,
        subscriptionId: product.id,
        eventName: eventName ?? (isRenewalEvent ? "did_renew_subscription" : "did_subscribe"),
      );
    } catch (err) {
      AppLogger.error(err.toString());
    }
  }

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
