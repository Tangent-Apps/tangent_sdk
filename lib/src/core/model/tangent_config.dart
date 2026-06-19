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

  /// Entitlement identifier granted to Superwall after a custom-paywall
  /// purchase (see [TangentSDK.purchaseProduct] → `_syncSubscriptionToSuperwall`).
  ///
  /// Must match the entitlement identifier configured in the app's Superwall
  /// dashboard. Apps differ — some use `Pro`, others `pro` — so this is
  /// configurable per app. Defaults to `'Pro'` to preserve existing behavior
  /// for apps that don't set it.
  final String proEntitlementId;

  /// Controls whether App Tracking Transparency (ATT) service is initialized.
  /// When enabled, the SDK will automatically initialize the ATT service on iOS
  /// Defaults to `true`.
  final bool enableAppTrackingTransparency;

  final String? adjustConsumableToken;

  /// Adjust event token for tracking when the user starts onboarding.
  /// Optional — only fires if provided. Used for funnel debugging, not Meta optimization.
  final String? adjustOnboardingStartedToken;

  /// Adjust event token for tracking when the user completes onboarding.
  /// Maps to Meta `CompleteRegistration` event via Adjust partner config.
  final String? adjustOnboardingCompletedToken;

  /// Adjust event token for tracking when a paywall screen becomes visible.
  /// Maps to Meta `ViewContent` event via Adjust partner config.
  final String? adjustPaywallShownToken;

  /// Adjust event token for tracking when the purchase/checkout sheet is displayed.
  /// Maps to Meta `InitiateCheckout` event via Adjust partner config.
  final String? adjustPaywallCheckoutShownToken;

  /// Controls whether `paywall_shown` is automatically tracked via Superwall delegate.
  ///
  /// When `true` (default): The SDK fires the Adjust event automatically when
  /// Superwall presents a paywall (via `didPresentPaywall` delegate).
  ///
  /// When `false`: You must manually call [trackPaywallShown].
  ///
  /// Requires [adjustPaywallShownToken] to be set.
  /// Defaults to `true`.
  final bool autoTrackPaywallShown;

  /// Controls whether `paywall_checkout_shown` is automatically tracked.
  ///
  /// When `true` (default): The SDK fires the Adjust event automatically when
  /// a purchase flow begins — via Superwall delegate (transaction start) or
  /// at the start of [purchaseProduct] for custom paywalls.
  ///
  /// When `false`: You must manually call [trackPaywallCheckoutShown].
  ///
  /// Requires [adjustPaywallCheckoutShownToken] to be set.
  /// Defaults to `true`.
  final bool autoTrackPaywallCheckoutShown;

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

  /// Controls whether Facebook App Events is enabled.
  ///
  /// When `true`: Initializes the Facebook SDK with auto-logging and advertiser tracking.
  /// Auto-logs app installs, app opens, and in-app purchases to Meta.
  ///
  /// Defaults to `false`.
  final bool enableFacebook;

  /// Controls whether Adjust is automatically initialized during SDK setup.
  ///
  /// When `true` (default): Adjust initializes immediately in [TangentSDK.initialize].
  /// When `false`: You must manually call [TangentSDK.instance.initAdjust()] when ready.
  ///
  /// Use `false` when the host app wants to delay Adjust init until after the ATT prompt.
  /// Defaults to `true`.
  final bool enableAutoInitAdjust;

  /// Product IDs that are **consumables** (e.g. one-time credits the user can
  /// buy repeatedly). On Android these must be explicitly *consumed* after the
  /// content is delivered, otherwise Google Play keeps reporting the item as
  /// owned ("You already own this item") and the user can never buy it again.
  ///
  /// The SDK consumes these (instead of only acknowledging) for both fresh
  /// `purchased` and redelivered `restored` events, so a purchase that was left
  /// unconsumed (crash/early-exit) is recovered on the next `restorePurchases`.
  ///
  /// Do NOT include subscriptions or permanent one-time products (e.g. lifetime
  /// access) here. iOS ignores this (StoreKit consumables finish on completion).
  /// Defaults to empty.
  final Set<String> consumableProductIds;

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
    this.proEntitlementId = 'Pro',
    this.enableAppTrackingTransparency = true,
    this.adjustConsumableToken,
    this.adjustOnboardingStartedToken,
    this.adjustOnboardingCompletedToken,
    this.adjustPaywallShownToken,
    this.adjustPaywallCheckoutShownToken,
    this.autoTrackPaywallShown = true,
    this.autoTrackPaywallCheckoutShown = true,
    this.enableMixpanelSubscriptionSync = true,
    this.enableFacebook = false,
    this.enableAutoInitAdjust = true,
    this.consumableProductIds = const <String>{},
  });
}
