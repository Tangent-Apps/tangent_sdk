import 'package:meta/meta.dart';
import 'package:tangent_sdk/src/core/enum/tangent_environment.dart';

@immutable
class TangentConfig {
  final String? mixpanelToken;
  final String? adjustAppToken;
  final TangentEnvironment? environment;
  final String? revenueCatApiKey;
  final bool enableCrashlytics;
  final bool enableAppCheck;
  final bool enableAnalytics;
  final bool enableRevenue;

  const TangentConfig({
    this.mixpanelToken,
    this.adjustAppToken,
    this.environment,
    this.revenueCatApiKey,
    this.enableCrashlytics = true,
    this.enableAppCheck = true,
    this.enableAnalytics = true,
    this.enableRevenue = true,
  });
}
