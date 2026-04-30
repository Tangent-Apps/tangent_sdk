# Early-Funnel Adjust Events Implementation

## Overview

Added early-funnel Adjust event tracking to the Tangent SDK for Meta optimization. These events allow tracking user progression through onboarding and paywall flows, mapped to Meta partner events via the Adjust dashboard.

## Events & Meta Mapping

| SDK Method | Config Token | Meta Partner Event | Purpose |
|---|---|---|---|
| `trackOnboardingStarted()` | `adjustOnboardingStartedToken` | — (funnel debugging only) | User starts onboarding |
| `trackOnboardingCompleted()` | `adjustOnboardingCompletedToken` | `CompleteRegistration` | User finishes onboarding |
| `trackPaywallShown()` | `adjustPaywallShownToken` | `ViewContent` | Paywall screen becomes visible |
| `trackPaywallCheckoutShown()` | `adjustPaywallCheckoutShownToken` | `InitiateCheckout` | Purchase/checkout sheet displayed |

## Files Changed

### `lib/src/core/model/tangent_config.dart`
- Added 4 optional token fields: `adjustOnboardingStartedToken`, `adjustOnboardingCompletedToken`, `adjustPaywallShownToken`, `adjustPaywallCheckoutShownToken`
- Added 2 auto-tracking bools: `autoTrackPaywallShown` (default `true`), `autoTrackPaywallCheckoutShown` (default `true`)

### `lib/src/services/adjust_analytics_service.dart`
- Added `trackFunnelEvent(String eventToken, {Map<String, String>? properties})` — fires token-only Adjust events (no revenue) with campaign params and SDK version

### `lib/src/tangent_sdk.dart`
- Added 4 public methods: `trackOnboardingStarted()`, `trackOnboardingCompleted()`, `trackPaywallShown()`, `trackPaywallCheckoutShown()`
- Added generic `trackAdjustEvent(String token, {Map<String, String>? properties})`
- Added `_fireAdjustFunnelEvent()` internal helper — validates token, fires event, logs
- Added `_setupSuperwallFunnelCallbacks()` — wires Superwall delegate callbacks for auto-firing
- Modified `purchaseProduct()` — auto-fires `paywall_checkout_shown` at start (custom paywall path)
- Modified `initSuperwall()` — calls `_setupSuperwallFunnelCallbacks()` after init

### `lib/src/services/superwall_service.dart`
- Added `onPaywallPresented` callback field — invoked from `didPresentPaywall()` delegate
- Added `onTransactionStart` callback field — invoked from `handleSuperwallEvent()` when `EventType.transactionStart`

### `lib/src/core/model/constants.dart`
- Bumped `tangentSdkVersion` to `0.4.0`

### `pubspec.yaml`
- Bumped version to `0.4.0`

### `CHANGELOG.md`
- Added `[0.4.0]` section documenting all new features

## Auto-Fire Logic

### Superwall Path
- `paywall_shown` → auto-fired via `didPresentPaywall()` delegate when `autoTrackPaywallShown == true`
- `paywall_checkout_shown` → auto-fired via `handleSuperwallEvent()` on `transactionStart` when `autoTrackPaywallCheckoutShown == true`

### Custom Paywall Path
- `paywall_shown` → must be called manually by the app
- `paywall_checkout_shown` → auto-fired at the start of `purchaseProduct()` when `autoTrackPaywallCheckoutShown == true`

### Error Handling
- All auto-fire paths use try/catch — failures are logged but never block the purchase flow
- Explicit calls throw `ConfigurationException` if token is missing, `ServiceNotInitializedException` if Adjust is not initialized

## Facebook App Events Integration

### `lib/src/services/facebook_service.dart` (new file)
- `FacebookService` with `initialize()` — enables auto-logging and advertiser tracking
- Auto-logs: app installs, app opens, in-app purchases (via StoreKit/Play Billing)

### Config
- `enableFacebook` bool in `TangentConfig` (default `false`)

### Wiring
- Initialized in `_initializeServices()` via `Future.wait` (parallel with other optional services)
- Complements Adjust funnel events — no overlap (Adjust handles funnel, Facebook handles install/open/purchase)

## Adjust Dashboard Setup (Manual)

For each event token, configure the Meta (Facebook) partner mapping:
1. Create event tokens in Adjust for each event
2. Link the Meta partner
3. Set mapped event names: `CompleteRegistration`, `ViewContent`, `InitiateCheckout`
