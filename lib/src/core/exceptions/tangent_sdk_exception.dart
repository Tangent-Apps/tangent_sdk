import 'package:meta/meta.dart';
import 'package:tangent_sdk/tangent_sdk.dart';

@immutable
abstract class TangentSDKException implements Exception {
  const TangentSDKException(this.message, {this.code, this.originalError});

  final String message;
  final String? code;
  final dynamic originalError;

  @override
  String toString() {
    final buffer = StringBuffer('TangentSDKException: $message');
    if (code != null) {
      buffer.write(' (Code: $code)');
    }
    if (originalError != null) {
      buffer.write('\nOriginal error: $originalError');
    }
    return buffer.toString();
  }
}

@immutable
class ServiceNotInitializedException extends TangentSDKException {
  const ServiceNotInitializedException(String serviceName)
    : super('$serviceName is not initialized. Call initialize() first.');
}

@immutable
class ServiceAlreadyInitializedException extends TangentSDKException {
  const ServiceAlreadyInitializedException(String serviceName) : super('$serviceName is already initialized.');
}

@immutable
class ServiceOperationException extends TangentSDKException {
  const ServiceOperationException(String operation, dynamic originalError, {String? code})
    : super('Failed to perform operation: $operation', code: code, originalError: originalError);
}

@immutable
class ConfigurationException extends TangentSDKException {
  const ConfigurationException(String message, {String? code}) : super(message, code: code);
}

@immutable
class NetworkException extends TangentSDKException {
  const NetworkException(String message, {String? code, dynamic originalError})
    : super(message, code: code, originalError: originalError);
}

@immutable
class PlatformException extends TangentSDKException {
  const PlatformException(String message, {String? code, dynamic originalError})
    : super(message, code: code, originalError: originalError);
}

@immutable
class ValidationException extends TangentSDKException {
  const ValidationException(String field, String reason) : super('Validation failed for $field: $reason');
}

@immutable
class AnalyticsException extends TangentSDKException {
  const AnalyticsException(String provider, String operation, {String? code, dynamic originalError})
    : super('Analytics error in $provider during $operation', code: code, originalError: originalError);
}

@immutable
class PurchaseException extends TangentSDKException {
  PurchaseException(String operation, {required PurchaseFailureCode code, dynamic originalError})
    : super('Purchase operation failed: $operation', code: code.name, originalError: originalError);
}

@immutable
class PurchaseMethodException extends TangentSDKException {
  const PurchaseMethodException(String operation, {dynamic originalError})
    : super('Purchase operation failed: $operation', originalError: originalError);
}

@immutable
class FirebaseException extends TangentSDKException {
  const FirebaseException(String service, String operation, {String? code, dynamic originalError})
    : super('Firebase $service error during $operation', code: code, originalError: originalError);
}

@immutable
class TimeoutException extends TangentSDKException {
  const TimeoutException(String operation, {Duration? timeout})
    : super('Operation timed out: $operation${timeout != null ? ' (timeout: ${timeout}s)' : ''}');
}

@immutable
class RateLimitException extends TangentSDKException {
  const RateLimitException(String service, {Duration? retryAfter})
    : super('Rate limit exceeded for $service${retryAfter != null ? ' (retry after: ${retryAfter}s)' : ''}');
}

@immutable
class AuthenticationException extends TangentSDKException {
  const AuthenticationException(String message, {String? code}) : super(message, code: code);
}

@immutable
class UnauthorizedException extends TangentSDKException {
  const UnauthorizedException(String operation) : super('Unauthorized to perform operation: $operation');
}
