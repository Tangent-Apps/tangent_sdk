# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
