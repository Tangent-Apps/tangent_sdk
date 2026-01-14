import 'package:flutter/foundation.dart';
import 'package:tangent_sdk/src/core/types/result.dart';

@immutable
abstract class CrashReportingService {
  const CrashReportingService();

  Future<Result<void>> initialize();
  
  Future<Result<void>> log(String message);
  
  Future<Result<void>> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    bool fatal = false,
    Map<String, String>? customKeys,
  });
  
  Future<Result<void>> recordFlutterError(
    FlutterErrorDetails errorDetails, {
    bool fatal = false,
  });
  
  Future<Result<void>> setCrashlyticsCollectionEnabled(bool enabled);
}
