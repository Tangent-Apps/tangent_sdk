# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the Tangent SDK - a comprehensive Flutter package that provides a unified wrapper for Firebase, Mixpanel, Adjust, Superwall (native mode), `in_app_purchase`, App Tracking Transparency, and In-App Review services. The SDK simplifies integration of analytics, crash reporting, in-app purchases, paywall management, and app review functionality in Flutter applications.

## Development Commands

### Package Management
```bash
# Install dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Analyze dependencies
flutter pub deps
```

### Code Quality
```bash
# Run static analysis
flutter analyze

# Apply linting rules (uses flutter_lints package)
dart analyze
```

### Testing
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run a specific test file
flutter test test/path/to/test_file.dart
```

Note: This project currently has minimal test coverage and lacks a comprehensive test suite.

### Building
```bash
# Build example app for iOS
flutter build ios

# Build example app for Android  
flutter build apk
```

## Architecture

### Core Structure

The SDK follows a service-oriented architecture with clear separation of concerns:

1. **Main Entry Point** (`lib/tangent_sdk.dart`): 
   - Exports all public APIs
   - Single barrel file for clean imports

2. **SDK Singleton** (`lib/src/tangent_sdk.dart`):
   - Central orchestrator managing all services
   - Handles initialization, configuration, and service coordination
   - Implements automatic error tracking and subscription renewal detection

3. **Service Layer**:
   - **Core Services** (`lib/src/core/service/`): Abstract interfaces defining service contracts
   - **Implementation Services** (`lib/src/services/`): Concrete implementations for each third-party SDK
     - `mixpanel_analytics_service.dart`: Mixpanel event tracking
     - `adjust_analytics_service.dart`: Adjust attribution and revenue tracking  
     - `iap_purchase_service.dart`: In-app purchase management via `in_app_purchase`
     - `superwall_service.dart`: Superwall paywall management (native mode, no PurchaseController)
     - `firebase_crash_reporting_service.dart`: Crashlytics integration
     - `firebase_app_check_service.dart`: App attestation
     - `app_tracking_transparency_service.dart`: iOS ATT handling
     - `app_review_service.dart`: In-app review prompts

4. **Core Components** (`lib/src/core/`):
   - **Models**: Data structures for products, purchases, customer info
   - **Types**: Result type for functional error handling
   - **Utils**: Logging, error handling utilities
   - **Exceptions**: Custom exception types for better error handling

### Key Design Patterns

- **Singleton Pattern**: TangentSDK uses a singleton to ensure single initialization
- **Result Type Pattern**: All revenue operations return `Result<T>` for explicit error handling
- **Service Abstraction**: Core service interfaces allow for easy testing and swapping implementations
- **Automatic Tracking**: Purchase failures and renewals are automatically tracked to analytics

### Subscription Renewal Detection

The SDK intelligently detects whether a purchase is a new subscription or a renewal by:
1. Checking existing purchase history before each purchase
2. Looking for an `originalPurchaseDate` in prior purchases
3. Routing to the appropriate Adjust event token (new vs renewal)

### Superwall Integration (Native Mode)

Superwall runs in **native mode** — no `PurchaseController` or RevenueCat dependency. Superwall handles its own purchase flow natively. The SDK coordinates subscription status between Superwall and `in_app_purchase` by calling `setSubscriptionStatus()` after successful purchases.

#### How it Works
1. **Paywall Display**: Superwall shows paywalls via `superwallRegisterPlacement()`
2. **Purchase Flow**: Purchases go through `purchaseProduct()` using `in_app_purchase`
3. **Subscription Sync**: After a successful purchase, the SDK sets Superwall subscription status to active
4. **Revenue Tracking**: Purchase events are forwarded to Adjust with proper revenue attribution
5. **Mixpanel Sync**: Subscription status is synced to Mixpanel user properties when enabled

## Important Notes

- The SDK requires Flutter 3.22.0+ and Dart SDK ^3.7.0
- All Firebase services are optional and controlled via `TangentConfig`
- In-app purchases use `in_app_purchase` (no RevenueCat dependency)
- Superwall runs in native mode (no `PurchaseController`)
- Adjust subscription tracking can be disabled via `automaticTrackSubscription` flag
- The SDK uses `firebase_core` v4.0.0+ and latest stable versions of all dependencies
- Uses `flutter_lints` v5.0.0+ with custom analysis options in `analysis_options.yaml`

## Code Quality Standards

The project enforces specific linting rules through `analysis_options.yaml`:
- Prefers const constructors and final fields
- Enforces return type declarations (`always_declare_return_types: true`)
- Requires package imports over relative imports (`always_use_package_imports: true`)
- Mandates end-of-file newlines (`eol_at_end_of_file: true`)
- Disables API documentation requirements for faster development (`public_member_api_docs: false`)