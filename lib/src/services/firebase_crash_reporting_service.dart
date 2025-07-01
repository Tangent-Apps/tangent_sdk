import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:tangent_sdk/src/core/service/crash_reporting_service.dart';
import '../core/types/result.dart';

@immutable
class FirebaseCrashReportingService implements CrashReportingService {
  const FirebaseCrashReportingService();

  @override
  Future<Result<void>> initialize() async {
    return resultOfAsync(() async {
      if (kDebugMode) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      }
      
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    });
  }



  @override
  Future<Result<void>> log(String message) async {
    return resultOfAsync(() async {
      await FirebaseCrashlytics.instance.log(message);
    });
  }

  @override
  Future<Result<void>> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    bool fatal = false,
    Map<String, String>? customKeys,
  }) async {
    return resultOfAsync(() async {
      if (customKeys != null) {
        customKeys.forEach((key, value) {
          FirebaseCrashlytics.instance.setCustomKey(key, value);
        });
      }
      
      await FirebaseCrashlytics.instance.recordError(
        exception,
        stackTrace,
        fatal: fatal,
      );
    });
  }

  @override
  Future<Result<void>> recordFlutterError(
    FlutterErrorDetails errorDetails, {
    bool fatal = false,
  }) async {
    return resultOfAsync(() async {
      if (fatal) {
        await FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      } else {
        await FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
      }
    });
  }

  @override
  Future<Result<void>> setCrashlyticsCollectionEnabled(bool enabled) async {
    return resultOfAsync(() async {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
    });
  }
}