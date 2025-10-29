import 'package:meta/meta.dart';
import 'package:tangent_sdk/src/core/enum/tangent_environment.dart';

@immutable
class TangentConfig {
  final String? mixpanelToken;
  final String? adjustAppToken;
  final TangentEnvironment? environment;
  final String? revenueCatApiKey;
  final String? adjustSubscriptionToken;
  final String? adjustSubscriptionRenewalToken;
  final bool enableCrashlytics;
  final bool enableAppCheck;
  final bool enableAnalytics;
  final bool enableRevenue;
  final bool automaticTrackSubscription;

  /// Controls whether Superwall paywall service is automatically initialized during SDK setup.
  ///
  /// When `true` (default): Superwall is initialized automatically when [TangentSDK.initialize] is called.
  ///
  /// When `false`: You must manually call [TangentSDK.instance.initSuperwall()] when you want to initialize Superwall.
  ///
  /// **Use cases for manual initialization:**
  /// - Initialize Superwall only after user authentication
  /// - Delay paywall initialization until specific app states
  /// - Initialize based on user subscription status or app configuration
  /// - Performance optimization by deferring non-critical services
  ///
  /// **Note:** RevenueCat service must be enabled (`enableRevenue: true`) and configured
  /// with a valid API key for Superwall to work properly.
  ///
  /// Defaults to `true`.
  final bool enableAutoInitSuperwall;
  final String? superwallIOSApiKey;
  final String? superwallAndroidApiKey;

  /// Controls whether App Tracking Transparency (ATT) service is initialized.
  /// When enabled, the SDK will automatically initialize the ATT service on iOS
  /// Defaults to `true`.
  final bool enableAppTrackingTransparency;

  final String? adjustConsumableToken;

  /// Controls whether RevenueCat-Adjust integration is enabled for precise revenue attribution.
  ///
  /// When `true` (default): The SDK automatically collects device identifiers (Adjust ID, IDFA, GPS AdId, IDFV)
  /// and sets them as subscriber attributes in RevenueCat. This enables accurate revenue tracking
  /// and attribution in Adjust for purchases made through RevenueCat.
  ///
  /// When `false`: Device identifiers are not collected or set in RevenueCat.
  ///
  /// **Requirements:**
  /// - Both `enableAnalytics` and `enableRevenue` must be `true`
  /// - `adjustAppToken` and `revenueCatApiKey` must be configured
  ///
  /// **How it works:**
  /// 1. After Adjust and RevenueCat are initialized, device identifiers are collected
  /// 2. Identifiers are automatically set as subscriber attributes in RevenueCat
  /// 3. RevenueCat forwards purchase events to Adjust with proper attribution
  /// 4. Revenue appears in Adjust dashboard with accurate campaign attribution
  ///
  /// **Note:** This integration is separate from the automatic subscription tracking
  /// (`automaticTrackSubscription`). This setting enables RevenueCat to send events
  /// directly to Adjust via server-to-server integration, while `automaticTrackSubscription`
  /// controls client-side event tracking.
  ///
  /// Reference: https://www.revenuecat.com/docs/integrations/attribution/adjust
  ///
  /// Defaults to `true`.
  final bool enableRevenueCatAdjustIntegration;

  const TangentConfig({
    this.mixpanelToken,
    this.adjustAppToken,
    this.adjustSubscriptionToken,
    this.adjustSubscriptionRenewalToken,
    this.environment,
    this.revenueCatApiKey,
    this.enableCrashlytics = true,
    this.enableAppCheck = true,
    this.enableAnalytics = true,
    this.enableRevenue = true,
    this.automaticTrackSubscription = true,
    this.enableAutoInitSuperwall = true,
    this.superwallIOSApiKey,
    this.superwallAndroidApiKey,
    this.enableAppTrackingTransparency = true,
    this.adjustConsumableToken,
    this.enableRevenueCatAdjustIntegration = true,
  });
}
