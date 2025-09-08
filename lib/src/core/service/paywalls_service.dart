import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import 'package:tangent_sdk/src/core/types/result.dart';

@immutable
abstract class PaywallsService {
  const PaywallsService();

  Future<Result<void>> initialize();

  Future<Result<void>> registerPlacement(String placement, {Map<String, Object>? params, Function? feature});

  Future<Result<void>> identifyUser(String userId);

  Future<Result<void>> setUserAttributes(Map<String, dynamic> attributes);

  Future<Result<void>> reset();

  Future<Result<void>> handleDeepLink(Uri url);

  Future<Result<void>> preloadPaywalls();

  Future<Result<void>> dismissPaywall();

  Future<Result<void>> setSubscriptionStatus({List<String> activeEntitlementIds = const []});

  Future<Result<void>> refreshSubscriptionStatus();
}
