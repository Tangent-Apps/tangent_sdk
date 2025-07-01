import 'package:meta/meta.dart';
import '../exceptions/tangent_sdk_exception.dart';
import '../types/result.dart';

@immutable
class ErrorHandler {
  const ErrorHandler._();

  static Future<Result<T>> handleAsync<T>(
    Future<T> Function() operation, {
    required String operationName,
    TangentSDKException Function(dynamic error)? errorMapper,
    void Function(TangentSDKException error)? onError,
  }) async {
    try {
      final result = await operation();
      return Success(result);
    } on TangentSDKException catch (e) {
      onError?.call(e);
      return Failure(e);
    } catch (e) {
      final mappedError = errorMapper?.call(e) ?? ServiceOperationException(operationName, e);
      onError?.call(mappedError);
      return Failure(mappedError);
    }
  }

  static Result<T> handle<T>(
    T Function() operation, {
    required String operationName,
    TangentSDKException Function(dynamic error)? errorMapper,
    void Function(TangentSDKException error)? onError,
  }) {
    try {
      final result = operation();
      return Success(result);
    } on TangentSDKException catch (e) {
      onError?.call(e);
      return Failure(e);
    } catch (e) {
      final mappedError = errorMapper?.call(e) ?? ServiceOperationException(operationName, e);
      onError?.call(mappedError);
      return Failure(mappedError);
    }
  }

  static Future<Result<T>> withRetry<T>(
    Future<T> Function() operation, {
    required String operationName,
    int maxRetries = 3,
    Duration delay = const Duration(milliseconds: 500),
    bool Function(TangentSDKException error)? shouldRetry,
    TangentSDKException Function(dynamic error)? errorMapper,
    void Function(TangentSDKException error, int attempt)? onRetry,
    void Function(TangentSDKException error)? onError,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      final result = await handleAsync(
        operation,
        operationName: operationName,
        errorMapper: errorMapper,
        onError: attempt == maxRetries ? onError : null,
      );

      if (result.isSuccess) {
        return result;
      }

      final error = result.error;

      if (attempt < maxRetries && (shouldRetry?.call(error) ?? true)) {
        onRetry?.call(error, attempt + 1);
        await Future.delayed(delay * (attempt + 1));
        continue;
      }

      onError?.call(error);
      return result;
    }

    // This should never be reached, but just in case
    return Failure(ServiceOperationException(operationName, 'Max retries exceeded'));
  }

  static Future<Result<T>> withTimeout<T>(
    Future<T> Function() operation, {
    required String operationName,
    required Duration timeout,
    TangentSDKException Function(dynamic error)? errorMapper,
    void Function(TangentSDKException error)? onError,
  }) async {
    try {
      final result = await operation().timeout(timeout);
      return Success(result);
    } on TangentSDKException catch (e) {
      onError?.call(e);
      return Failure(e);
    } catch (e) {
      final mappedError =
          errorMapper?.call(e) ??
          (e is TimeoutException ? TimeoutException(operationName, timeout: timeout) : ServiceOperationException(operationName, e));
      onError?.call(mappedError);
      return Failure(mappedError);
    }
  }

  static TangentSDKException mapFirebaseError(dynamic error, String operation) {
    if (error.toString().contains('network')) {
      return NetworkException('Firebase network error during $operation', originalError: error);
    }
    if (error.toString().contains('auth')) {
      return AuthenticationException('Firebase authentication error during $operation');
    }
    return FirebaseException('Firebase', operation, originalError: error);
  }

  static TangentSDKException mapPurchaseError(dynamic error, String operation) {
    return PurchaseException(operation, originalError: error);
  }

  static TangentSDKException mapAnalyticsError(String provider, dynamic error, String operation) {
    return AnalyticsException(provider, operation, originalError: error);
  }

  static bool isRetryableError(TangentSDKException error) {
    return error is NetworkException || error is TimeoutException || error is RateLimitException;
  }

  static bool isNetworkError(TangentSDKException error) {
    return error is NetworkException;
  }

  static bool isConfigurationError(TangentSDKException error) {
    return error is ConfigurationException || error is ValidationException;
  }

  static bool isAuthError(TangentSDKException error) {
    return error is AuthenticationException || error is UnauthorizedException;
  }
}
