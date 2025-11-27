import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:tangent_sdk/src/core/service/purchases_service.dart';
import 'package:tangent_sdk/src/core/utils/app_logger.dart';
import 'package:tangent_sdk/src/services/superwall_service.dart';
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
  PaywallsService? _superwallService;

  // Stream controller for successful purchases
  late final StreamController<Product> _successPurchaseController;

  // Deduplication tracking
  final Map<String, DateTime> _lastEmissionTimes = {};
  static const Duration _deduplicationWindow = Duration(milliseconds: 1000); // 1 second window

  // Purchase context storage for automatic tracking
  Map<String, String>? _pendingPurchaseContext;

  TangentSDK._(this._config) {
    _successPurchaseController = StreamController<Product>.broadcast();
  }

  static TangentSDK get instance {
    if (_instance == null) {
      throw const ServiceNotInitializedException('TangentSDK');
    }
    return _instance!;
  }

  /// Dispose of resources
  void dispose() {
    AppLogger.info('Disposing TangentSDK resources', tag: 'TangentSDK');
    _successPurchaseController.close();
    _lastEmissionTimes.clear();
    _pendingPurchaseContext = null;
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
  ///
  /// This method should be called after initializing the SDK.
  ///
  /// [config] The configuration object containing the SDK settings.
  /// [firebaseOptions] Optional Firebase options for initializing Firebase.
  Future<void> _initializeServices() async {
    AdjustAnalyticsService? adjust;

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
        adjust = AdjustAnalyticsService(_config.adjustAppToken!, _config.environment!);
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

    // Initialize purchases service
    if (_config.enableRevenue && _config.revenueCatApiKey != null) {
      AppLogger.info('Initializing RevenueCat Service', tag: 'Revenue');
      _revenueService = RevenueCatService(
        _config.revenueCatApiKey!,
        enableAdjustIntegration: _config.enableRevenueCatAdjustIntegration,
      );
      await _revenueService!.initialize();
      AppLogger.info('RevenueCat Service initialized', tag: 'Revenue');

      // Set up RevenueCat-Adjust integration if both services are enabled
      if (_config.enableRevenueCatAdjustIntegration && _config.adjustAppToken != null) {
        AppLogger.info('Setting up RevenueCat-Adjust integration', tag: 'Revenue');
        if (adjust != null) {
          final identifiers = await (_revenueService! as RevenueCatService).setupAdjustIntegration(
            adjustAnalyticsService: adjust,
          );
          AppLogger.info(
            'RevenueCat-Adjust integration configured with ${identifiers.length} identifiers',
            tag: 'Revenue',
          );
        }
      }
    }

    await Future.wait([
      // Initialize Superwall service
      if (_config.enableAutoInitSuperwall) initSuperwall(),

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
  /// - RevenueCat service must be initialized first (enabled via `enableRevenue: true`)
  /// - iOS API key must be provided via `superwallIOSApiKey` in [TangentConfig]
  /// - Android API key is optional (can be empty string)
  ///
  /// **Example usage:**
  /// ```dart
  /// // Option 1: Automatic initialization (default)
  /// final config = TangentConfig(
  ///   superwallIOSApiKey: 'your_ios_key',
  ///   enableAutoInitSuperwall: true, // Default
  /// );
  /// await TangentSDK.initialize(config: config);
  /// // Superwall is now ready to use
  ///
  /// // Option 2: Manual initialization
  /// final config = TangentConfig(
  ///   superwallIOSApiKey: 'your_ios_key',
  ///   enableAutoInitSuperwall: false,
  /// );
  /// await TangentSDK.initialize(config: config);
  /// // Initialize Superwall later when needed
  /// await TangentSDK.instance.initSuperwall();
  /// ```
  ///
  /// **Note:** This method is safe to call multiple times. If Superwall is already
  /// initialized, subsequent calls will be ignored.
  Future<void> initSuperwall() async {
    if (_config.superwallIOSApiKey != null) {
      AppLogger.info('Initializing Superwall Service', tag: superwallTag);
      final info = await _revenueService!.getCustomerPurchasesInfo();
      final userId = info.data.originalAppUserId;
      _superwallService ??= SuperwallService(
        iOSApiKey: _config.superwallIOSApiKey!,
        androidApiKey: _config.superwallAndroidApiKey ?? "",
        revenueCarUserId: userId,
        // Set up purchase callback to track events to Adjust
        onSubscriptionPurchaseCompleted: _onSubscriptionPurchaseCompleted,
        onConsumablePurchaseCompleted: _onConsumablePurchaseCompleted,
      );

      // Initialize Superwall with RevenueCat integration if available
      await _superwallService!.initialize();

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

  // Revenue Methods
  Future<Result<List<Product>>> getProducts(List<String> productIds) async {
    return await _revenueService?.getProducts(productIds) ?? const Success([]);
  }

  /// Purchase a product by id
  /// Returns a [Result] of [CustomerPurchasesInfo]
  /// Automatically tracks subscription events
  /// Automatically tracks failure events
  Future<Result<Product>> purchaseProductById(
    String productId, {
    String? eventToken,
    String? eventName,
    Map<String, String>? context,
  }) async {
    // Check if this is a renewal before making the purchase
    final isRenewal = await _checkIsRenewal(productId);
    // Use provided context or fallback to pending context
    final finalContext = context ?? _pendingPurchaseContext;
    final productResult = await _revenueService?.purchaseProductById(productId);

    if (productResult == null) {
      throw const ServiceNotInitializedException('PurchasesService');
    }

    if (productResult.isSuccess) {
      final product = productResult.data;
      if (finalContext != null) {
        AppLogger.info('Using purchase context: ${finalContext.keys.join(', ')}', tag: 'PurchaseContext');
      }

      await _silentTrackSubscriptionEvent(
        product: product,
        isRenewalEvent: isRenewal,
        eventName: eventName,
        eventToken: eventToken,
        context: finalContext,
      );

      // Clear pending context after use
      _pendingPurchaseContext = null;

      return Success(product);
    } else {
      await _trackPurchaseFailureEvent(failure: productResult.error, productId: productId);
      return Failure(productResult.error);
    }
  }

  /// Make a purchase
  /// Returns a [Result] of [CustomerPurchasesInfo]
  /// Automatically tracks subscription events
  /// Automatically tracks failure events
  Future<Result<CustomerPurchasesInfo>> purchaseProduct(
    Product product, {
    String? eventToken,
    String? eventName,
    Map<String, String>? context,
  }) async {
    // Check if this is a renewal before making the purchase
    final isRenewal = await _checkIsRenewal(product.id);
    // Use provided context or fallback to pending context
    final finalContext = context ?? _pendingPurchaseContext;
    final productResult = await _revenueService?.purchaseProduct(product);

    if (productResult == null) {
      throw const ServiceNotInitializedException('PurchasesService');
    }

    if (productResult.isSuccess) {
      final customerPurchasesInfo = productResult.data;
      if (finalContext != null) {
        AppLogger.info('Using purchase context: ${finalContext.keys.join(', ')}', tag: 'PurchaseContext');
      }

      _silentTrackSubscriptionEvent(
        product: product,
        isRenewalEvent: isRenewal,
        eventToken: eventToken,
        eventName: eventName,
        context: finalContext,
      );

      // Clear pending context after use
      _pendingPurchaseContext = null;

      return Success(customerPurchasesInfo);
    } else {
      await _trackPurchaseFailureEvent(
        failure: productResult.error,
        productId: product.id,
        productTitle: product.title,
        productPrice: product.priceString,
        productCurrencyCode: product.currencyCode,
      );
      return Failure(productResult.error);
    }
  }

  Future<Result<bool>> checkActiveSubscription() async {
    return await _revenueService?.checkActiveSubscription() ?? const Success(false);
  }

  Future<Result<bool>> checkActiveSubscriptionToEntitlement(String entitlementId) async {
    return await _revenueService?.checkActiveSubscriptionToEntitlement(entitlementId) ?? const Success(false);
  }

  Future<Result<CustomerPurchasesInfo>> restorePurchases() async {
    return await _revenueService?.restorePurchases() ??
        const Success(
          CustomerPurchasesInfo(
            hasActiveSubscription: false,
            originalAppUserId: '',
            purchases: [],
            managementURL: null,
          ),
        );
  }

  Future<Result<void>> logIn(String appUserId) async {
    return await _revenueService?.logIn(appUserId) ?? const Failure(ServiceNotInitializedException('PurchasesService'));
  }

  Future<Result<List<Product>>> getOffering(String offeringId) async {
    return await _revenueService?.getOffering(offeringId) ?? const Success([]);
  }

  Future<Result<List<Product>>> getOfferings() async {
    return await _revenueService?.getOfferings() ?? const Success([]);
  }

  Stream<CustomerPurchasesInfo> get customerPurchasesInfoStream =>
      _revenueService?.customerPurchasesInfoStream ?? const Stream.empty();

  /// Stream of successful purchases
  Stream<Product> get successPurchaseStream {
    return _successPurchaseController.stream;
  }

  /// Emit product to success stream with deduplication
  void _emitToSuccessStream(Product product) {
    final now = DateTime.now();
    final lastEmissionTime = _lastEmissionTimes[product.id];

    // Check if we should emit (no previous emission or outside deduplication window)
    if (lastEmissionTime == null || now.difference(lastEmissionTime) > _deduplicationWindow) {
      _lastEmissionTimes[product.id] = now;
      _successPurchaseController.add(product);
      AppLogger.info('✅ Emitted ${product.id} to success stream', tag: 'PurchaseStream');
    } else {
      final timeSinceLastEmission = now.difference(lastEmissionTime);
      AppLogger.info(
        '🚫 Blocked duplicate emission of ${product.id} (${timeSinceLastEmission.inMilliseconds}ms ago)',
        tag: 'PurchaseStream',
      );
    }
  }

  Future<Result<String?>> getManagementUrl() async {
    return await _revenueService?.getManagementUrl() ?? const Success(null);
  }

  Future<Result<List<Entitlement>>> getEntitlements() async {
    return await _revenueService?.getEntitlements() ?? const Success([]);
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
    Map<String, String>? context,
  }) async {
    try {
      await trackSubscription(
        eventToken:
            eventToken ?? (isRenewalEvent ? _config.adjustSubscriptionRenewalToken! : _config.adjustSubscriptionToken!),
        price: product.price,
        currency: product.currencyCode,
        subscriptionId: product.id,
        eventName: eventName ?? (isRenewalEvent ? "subscription_renewed" : "subscribe"),
        context: context,
      );
    } catch (err) {
      AppLogger.error(err.toString());
    }
  }

  /// Private method to track purchase failure events based on failure code
  Future<void> _trackPurchaseFailureEvent({
    required TangentSDKException failure,
    required String productId,
    String? productTitle,
    String? productPrice,
    String? productCurrencyCode,
  }) async {
    final String failureReason;
    final String errorCode;
    final String eventName;

    if (failure is PurchaseException) {
      failureReason = failure.code ?? PurchaseFailureCode.unknown.name;
      errorCode = failure.code ?? PurchaseFailureCode.unknown.name;

      // Check if user cancelled the purchase
      if (failure.code == PurchaseFailureCode.userCancelled.name) {
        eventName = 'purchase_cancelled';
      } else if (failure.code == PurchaseFailureCode.network.name) {
        eventName = 'purchase_failed';
      } else {
        eventName = 'error_while_making_purchase';
      }
    } else {
      failureReason = failure.message;
      errorCode = failure.code ?? PurchaseFailureCode.unknown.name;
      eventName = 'error_while_making_purchase';
    }

    final properties = <String, Object>{
      'original_error': failure.originalError.toString(),
      'product_id': productId,
      'purchase_error_code': errorCode,
    };

    if (productTitle != null) properties['product_title'] = productTitle;
    if (productPrice != null) properties['product_price'] = productPrice;
    if (productCurrencyCode != null) properties['product_currency_code'] = productCurrencyCode;

    await trackFailureEvent(eventName: eventName, failureReason: failureReason, properties: properties);
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

  // Purchase Context Methods
  /// Set purchase context that will be automatically included in the next purchase event.
  /// This context will be sent to both Adjust and Mixpanel when a purchase is completed.
  ///
  /// Example usage:
  /// ```dart
  /// TangentSDK.instance.setPurchaseContext({
  ///   'book_title': 'Flutter Mastery',
  ///   'chapter': 'Chapter 5',
  ///   'source_screen': 'reading_page'
  /// });
  ///
  /// // User purchases through Superwall - context automatically included
  /// await TangentSDK.instance.superwallRegisterPlacement('pro_upgrade');
  /// ```
  void setPurchaseContext(Map<String, String> context) {
    _pendingPurchaseContext = context;
    AppLogger.info('Purchase context set with keys: ${context.keys.join(', ')}', tag: 'PurchaseContext');
  }

  /// Clear any pending purchase context
  void clearPurchaseContext() {
    _pendingPurchaseContext = null;
    AppLogger.info('Purchase context cleared', tag: 'PurchaseContext');
  }

  /// Get the current pending purchase context (readonly)
  Map<String, String>? get purchaseContext => _pendingPurchaseContext;

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

  /// Handle Superwall purchase completion and track to Adjust
  /// This method is called automatically when a purchase is completed through Superwall
  Future<void> _onSubscriptionPurchaseCompleted(Product product) async {
    final isRenewal = await _checkIsRenewal(product.id);
    final context = _pendingPurchaseContext;

    try {
      AppLogger.info('Handling Superwall purchase: ${product.id}', tag: superwallTag);
      if (context != null) {
        AppLogger.info('Using purchase context: ${context.keys.join(', ')}', tag: superwallTag);
      }

      // Track the purchase to Adjust using the same logic as regular purchases
      await _silentTrackSubscriptionEvent(product: product, isRenewalEvent: isRenewal, context: context);

      // Clear context after use
      _pendingPurchaseContext = null;

      // Emit to success purchase stream with deduplication
      _emitToSuccessStream(product);

      AppLogger.info('Superwall purchase tracked successfully to Adjust', tag: superwallTag);
    } catch (e) {
      AppLogger.error('Failed to track Superwall purchase to Adjust', error: e, tag: superwallTag);
    }
  }

  /// Handle Superwall Consumable purchase completion and track to Adjust
  /// This method is called automatically when a purchase is completed through Superwall
  Future<void> _onConsumablePurchaseCompleted(Product product) async {
    final context = _pendingPurchaseContext;

    try {
      AppLogger.info('Handling Superwall Consumable Purchase: ${product.id}', tag: superwallTag);
      if (context != null) {
        AppLogger.info('Using purchase context: ${context.keys.join(', ')}', tag: superwallTag);
      }

      // Track to Adjust only if token is configured
      if (_config.adjustConsumableToken != null) {
        await trackSubscription(
          eventToken: _config.adjustConsumableToken!,
          price: product.price,
          currency: product.currencyCode,
          subscriptionId: product.id,
          eventName: "coin_purchase",
          context: context,
        );
      }

      // Clear context after use
      _pendingPurchaseContext = null;

      // Emit to success purchase stream with deduplication
      _emitToSuccessStream(product);

      AppLogger.info('Superwall consumable purchase tracked successfully', tag: superwallTag);
    } catch (e) {
      AppLogger.error('Failed to track Superwall purchase to Adjust', error: e, tag: superwallTag);
    }
  }
}
