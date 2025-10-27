# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- ...

### Changed

- ...

### Fixed

- ...

### Deprecated

- ...

### Removed

- ...

### Security

- ...

## [0.0.13] - 2025-10-27

### Changed

- Version bump for package release

## [0.0.12] - 2025-10-27

### Updated

- Updated dependencies to their latest versions:
  - `adjust_sdk: ^5.4.5` (from ^5.4.0)

## [0.0.11] - 2025-09-29

### Added

- Success purchases controller/stream in `TangentSDK`:
  - `successPurchaseStream` to listen for successful purchases across both RevenueCat and Superwall flows.
  - Deduplication window (1s) to avoid duplicate emissions.

### Changed

- Renamed `SuperwallPurchaseCallback` to `PurchaseCallback` for consistency and reuse.
- Emitting successful purchases from RevenueCat purchase methods to the success stream.

## [0.0.9] - 2025-09-25

### Enhanced

- **Improved Logging System**:

  - Added comprehensive `AppLogger` integration throughout the SDK
  - Enhanced `RCPurchaseController` with tagged logging using 💳 emoji for purchase operations
  - Added detailed logging for purchase flow tracking, error handling with stack traces
  - Improved error visibility for debugging RevenueCat purchase operations

- **Better Superwall Configuration Control**:

  - Renamed `autoInitSuperwall` to `enableAutoInitSuperwall` for clearer developer intent
  - Added comprehensive documentation for `initSuperwall()` method
  - Enhanced flexibility for automatic vs manual Superwall initialization
  - Added detailed use cases and examples for different initialization patterns

- **SDK Architecture Improvements**:
  - Refactored service initialization to use `Future.wait()` for parallel initialization
  - Separated crash reporting, app check, and ATT initialization into dedicated methods
  - Improved service startup performance and error isolation
  - Enhanced method naming consistency across Superwall API methods

### Changed

- **Configuration Property Naming**:

  - `autoInitSuperwall` → `enableAutoInitSuperwall` with enhanced documentation
  - Better clarity on when to use automatic vs manual Superwall initialization

- **Method Naming Consistency**:
  - Prefixed all Superwall methods with `superwall` for better API organization
  - `registerPlacement()` → `superwallRegisterPlacement()`
  - `identifySuperwallUser()` → `superwallIdentifySuperwallUser()`
  - `setSuperwallUserAttributes()` → `superwallSetUserAttributes()`
  - `resetSuperwall()` → `superwallReset()`
  - `handleSuperwallDeepLink()` → `superwallHandleDeepLink()`
  - `setSuperwallSubscriptionStatus()` → `superwallSetSubscriptionStatus()`

### Fixed

- **Purchase Flow Error Handling**:
  - Enhanced error logging with proper stack traces in `RCPurchaseController`
  - Added comprehensive error tracking for product not found scenarios
  - Improved purchase failure detection and reporting
  - Better error context for Google Play subscription option failures

## [0.0.8] - 2025-09-08

### Added

- **Superwall Integration**: Complete paywall management system with Superwall SDK

  - Added `PaywallsService` interface for paywall operations
  - Implemented `SuperwallService` with RevenueCat purchase controller integration
  - Added `RCPurchaseController` for seamless RevenueCat-Superwall integration
  - New configuration options: `enableSuperwall`, `superwallIOSApiKey`, `superwallAndroidApiKey`
  - Automatic user identification using RevenueCat user ID
  - Automatic subscription status synchronization between RevenueCat and Superwall

- **New SDK Methods for Paywall Management**:
  - `registerPlacement()` - Register paywall placements with optional parameters
  - `identifySuperwallUser()` - Identify users for personalized paywalls
  - `setSuperwallUserAttributes()` - Set user attributes for targeting
  - `resetSuperwall()` - Reset Superwall session
  - `handleSuperwallDeepLink()` - Handle deep links through Superwall
  - `preloadPaywalls()` - Preload paywalls for better performance
  - `dismissPaywall()` - Programmatically dismiss paywalls
  - `setSuperwallSubscriptionStatus()` - Set subscription status with entitlements
  - `refreshSuperwallSubscriptionStatus()` - Refresh subscription status

### Changed

- Updated package description to include Superwall capabilities
- Enhanced SDK architecture to support paywall services

### Dependencies

- Added `superwallkit_flutter: ^2.4.2` for paywall management

## [0.0.7] - 2025-09-04

### Added

- `logIn(String appUserId)` method for user authentication with RevenueCat
- Support for linking app user IDs to RevenueCat customer profiles
- Automatic customer info updates after successful login

## [0.0.6] - 2025-08-23

### Fixed

- Fixed purchase failure log event not being sent to analytics services due to improper async handling
- Fixed async/await handling in `purchaseProduct` and `purchaseProductById` methods
- Fixed Result type handling when calling analytics services

### Changed

- Unified event naming for better analytics tracking:
  - User cancelled purchases now log as `purchase_cancelled`
  - Network failures log as `purchase_failed`
  - Subscription renewals log as `subscription_renewed` (was `did_renew_subscription`)
  - New subscriptions log as `subscribe` (was `did_subscribe`)
- Created private `_trackPurchaseFailureEvent` method to centralize failure tracking logic

## [0.0.5] - 2025-07-30

### Updated

- Added `managementURL`.

- Updated Firebase dependencies to their latest stable versions:
  - `firebase_core: ^4.0.0`
  - `firebase_crashlytics: ^5.0.0`
  - `firebase_app_check: ^0.4.0`

## [0.0.4] - 2025-07-18

### Fixed

- Fixed not logging event on purchase failure.

## [0.0.3] - 2025-07-17

### Added

- `CustomerPurchasesInfo` model and `customerPurchasesInfoStream` for real-time subscription updates.
- `purchaseProduct` method and refactored `purchaseProductById` for improved flow.
- `checkActiveSubscriptionToEntitlement()` method for checking specific entitlement access.
- `restorePurchases()` method for restoring previous purchases.
- `getOffering()` and `getOfferings()` methods for retrieving RevenueCat offerings.
- Automatic detection of renewal subscriptions and logging to Adjust as renewal events.
- Automatic subscription-tracking & failure-event logging through the new purchase APIs.
- `automaticTrackSubscription`, `adjustSubscriptionToken`, and `adjustSubscriptionRenewalToken` configuration options.
- Enhanced method documentation with detailed descriptions and examples.

### Changed

- Bumped `purchases_flutter` dependency to **8.10.6**.
- Added dedicated `PurchaseFailureCode` values for common purchase errors to simplify error handling.
- Updated README with comprehensive documentation for all new methods and features.

### Fixed

- Fixed "failure code null" error in purchase operations by resolving `PlatformException` type casting conflicts.
- Improved error handling in RevenueCat service to properly extract failure codes.
- Resolved type casting issues between Flutter's `PlatformException` and custom `PlatformException` classes.

### Removed

- Deprecated `hasActiveSubscription` in favour of `customerPurchasesInfoStream`.

## [0.0.2] - 2025-07-02

### Added

- add when and whenAsync for pattern matching on Result

## [0.0.1] - 2025-07-01

### Added

- Initial release of Tangent SDK
- Firebase integration (Crashlytics, App Check)
- Analytics services (Mixpanel, Adjust)
- Revenue management with RevenueCat
- App Tracking Transparency support
- In-App Review functionality
- Unified error handling and logging
- Debug logging with emoji indicators
- Comprehensive configuration options
- Result-based error handling pattern

### Features

- **Firebase Services**:
  - Crashlytics for crash reporting
  - App Check for app authentication
- **Analytics**:
  - Mixpanel event tracking and failure events
  - Adjust subscription and revenue tracking
- **Revenue Management**:
  - Product fetching and purchasing
  - Subscription management
  - Active subscription monitoring
  - Purchase restoration
- **Utility Services**:
  - App Tracking Transparency (iOS 14.5+)
  - In-App Review requests
  - Store listing navigation

### Dependencies

- firebase_core: ^3.14.0
- firebase_crashlytics: ^4.3.7
- firebase_app_check: ^0.3.2+7
- mixpanel_flutter: ^2.4.0
- adjust_sdk: ^5.4.0
- purchases_flutter: ^8.10.4
- app_tracking_transparency: ^2.0.6+1
- in_app_review: ^2.0.10
- meta: ^1.11.0
