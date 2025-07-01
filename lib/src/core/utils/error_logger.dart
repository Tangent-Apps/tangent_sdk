// import 'package:meta/meta.dart';
// import '../exceptions/tangent_sdk_exception.dart';
// import '../service/crash_reporting_service.dart';

// @immutable
// class ErrorLogger {
//   const ErrorLogger._();

//   static CrashReportingService? _crashReporting;

//   static void initialize(CrashReportingService crashReporting) {
//     _crashReporting = crashReporting;
//   }

//   static Future<void> logError(
//     TangentSDKException error, {
//     StackTrace? stackTrace,
//     bool fatal = false,
//     Map<String, String>? customKeys,
//     String? userId,
//     String? sessionId,
//   }) async {
//     await _crashReporting?.recordError(
//       error, 
//       stackTrace, 
//       fatal: fatal, 
//       customKeys: {
//         'error_type': error.runtimeType.toString(),
//         'error_code': error.code ?? 'unknown',
//         'error_message': error.message,
//         if (userId != null) 'user_id': userId,
//         if (sessionId != null) 'session_id': sessionId,
//         ...?customKeys,
//       },
//     );

//     // Log to console in debug mode
//     if (_isDebugMode()) {
//       print('TangentSDK Error: ${error.toString()}');
//       if (stackTrace != null) {
//         print('Stack trace: $stackTrace');
//       }
//     }
//   }

//   static Future<void> logMessage(
//     String message, {
//     LogLevel level = LogLevel.info,
//     Map<String, String>? customKeys,
//     String? userId,
//     String? sessionId,
//   }) async {
//     final formattedMessage = '[${level.name.toUpperCase()}] $message';
    
//     await _crashReporting?.log(formattedMessage);

//     // Log to console in debug mode
//     if (_isDebugMode()) {
//       print('TangentSDK: $formattedMessage');
//     }
//   }

//   static Future<void> logOperationStart(String operation, {Map<String, String>? parameters}) async {
//     await logMessage(
//       'Operation started: $operation',
//       level: LogLevel.debug,
//       customKeys: parameters,
//     );
//   }

//   static Future<void> logOperationSuccess(String operation, {Map<String, String>? result}) async {
//     await logMessage(
//       'Operation completed successfully: $operation',
//       level: LogLevel.info,
//       customKeys: result,
//     );
//   }

//   static Future<void> logOperationFailure(
//     String operation, 
//     TangentSDKException error, {
//     StackTrace? stackTrace,
//     Map<String, String>? customKeys,
//   }) async {
//     await logError(
//       error,
//       stackTrace: stackTrace,
//       customKeys: {
//         'operation': operation,
//         ...?customKeys,
//       },
//     );
//   }

//   static Future<void> logRetry(String operation, int attempt, TangentSDKException error) async {
//     await logMessage(
//       'Retrying operation: $operation (attempt $attempt) - ${error.message}',
//       level: LogLevel.warning,
//       customKeys: {
//         'operation': operation,
//         'attempt': attempt.toString(),
//         'error_type': error.runtimeType.toString(),
//       },
//     );
//   }

//   static Future<void> logUserAction(String action, {Map<String, String>? properties}) async {
//     await logMessage(
//       'User action: $action',
//       level: LogLevel.info,
//       customKeys: properties,
//     );
//   }

//   static Future<void> logPerformanceMetric(
//     String operation, 
//     Duration duration, {
//     Map<String, String>? additionalMetrics,
//   }) async {
//     await logMessage(
//       'Performance: $operation took ${duration.inMilliseconds}ms',
//       level: LogLevel.info,
//       customKeys: {
//         'operation': operation,
//         'duration_ms': duration.inMilliseconds.toString(),
//         ...?additionalMetrics,
//       },
//     );
//   }

//   static bool _isDebugMode() {
//     bool inDebugMode = false;
//     assert(inDebugMode = true);
//     return inDebugMode;
//   }
// }

// enum LogLevel {
//   debug,
//   info,
//   warning,
//   error,
// }