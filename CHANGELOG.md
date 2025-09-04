# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
