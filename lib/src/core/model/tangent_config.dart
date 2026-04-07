// src/core/model/tangent_config.dart
import 'package:meta/meta.dart';
import 'package:tangent_sdk/src/core/enum/tangent_environment.dart';

@immutable
class TangentConfig {
  final String? mixpanelToken;
  final String? adjustAppToken;
  final TangentEnvironment? environment;
  final String? adjustSubscriptionToken;
  final String? adjustSubscriptionRenewalToken;
  final bool enableCrashlytics;
  final bool enableAppCheck;
  final bool enableAnalytics;
  final bool automaticTrackSubscription;

  /// Controls whether Superwall paywall service is enabled.
  ///
  /// When `true` (default): Superwall is initialized during SDK setup.
  ///
  /// When `false`: Superwall is not initialized.
  ///
  /// Defaults to `true`.
  final bool enableSuperwall;

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
  /// Defaults to `true`.
  final bool enableAutoInitSuperwall;
  final String? superwallIOSApiKey;
  final String? superwallAndroidApiKey;

  /// Controls whether App Tracking Transparency (ATT) service is initialized.
  /// When enabled, the SDK will automatically initialize the ATT service on iOS
  /// Defaults to `true`.
  final bool enableAppTrackingTransparency;

  final String? adjustConsumableToken;

  /// Controls whether subscription data is automatically synced to Mixpanel People.
  ///
  /// When `true` (default): The SDK automatically syncs subscription data to Mixpanel People
  /// as user profile properties after successful purchases and restores.
  ///
  /// When `false`: No automatic syncing occurs. You can still manually call `syncSubscriptionToMixpanel()`.
  ///
  /// **What gets synced:**
  /// - `has_active_subscription` - Boolean subscription status
  ///
  /// **Requirements:**
  /// - `mixpanelToken` must be configured
  ///
  /// Defaults to `true`.
  final bool enableMixpanelSubscriptionSync;

  /// Controls whether Adjust is automatically initialized during SDK setup.
  ///
  /// When `true` (default): Adjust initializes immediately in [TangentSDK.initialize].
  /// When `false`: You must manually call [TangentSDK.instance.initAdjust()] when ready.
  ///
  /// Use `false` when the host app wants to delay Adjust init until after the ATT prompt.
  /// Defaults to `true`.
  final bool enableAutoInitAdjust;

  const TangentConfig({
    this.mixpanelToken,
    this.adjustAppToken,
    this.adjustSubscriptionToken,
    this.adjustSubscriptionRenewalToken,
    this.environment,
    this.enableCrashlytics = true,
    this.enableAppCheck = true,
    this.enableAnalytics = true,
    this.automaticTrackSubscription = true,
    this.enableSuperwall = true,
    this.enableAutoInitSuperwall = true,
    this.superwallIOSApiKey,
    this.superwallAndroidApiKey,
    this.enableAppTrackingTransparency = true,
    this.adjustConsumableToken,
    this.enableMixpanelSubscriptionSync = true,
    this.enableAutoInitAdjust = true,
  });
}
