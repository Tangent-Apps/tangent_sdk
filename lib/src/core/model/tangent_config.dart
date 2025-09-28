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
  });
}
