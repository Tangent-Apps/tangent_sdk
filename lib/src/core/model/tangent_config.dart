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
  final bool enableSuperwall;
  final String? superwallIOSApiKey;
  final String? superwallAndroidApiKey;

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
    this.enableSuperwall = true,
    this.superwallIOSApiKey,
    this.superwallAndroidApiKey,
  });
}
