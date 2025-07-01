import 'package:meta/meta.dart';
import '../exceptions/tangent_sdk_exception.dart';

@immutable
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T get data {
    if (this is Success<T>) {
      return (this as Success<T>).data;
    }
    throw StateError('Cannot access data on a failure result');
  }

  TangentSDKException get error {
    if (this is Failure<T>) {
      return (this as Failure<T>).error;
    }
    throw StateError('Cannot access error on a success result');
  }

  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(TangentSDKException error) onFailure,
  }) {
    return switch (this) {
      Success<T>(data: final data) => onSuccess(data),
      Failure<T>(error: final error) => onFailure(error),
    };
  }

  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success<T>(data: final data) => Success(transform(data)),
      Failure<T>(error: final error) => Failure(error),
    };
  }

  Result<R> flatMap<R>(Result<R> Function(T data) transform) {
    return switch (this) {
      Success<T>(data: final data) => transform(data),
      Failure<T>(error: final error) => Failure(error),
    };
  }

  T getOrElse(T Function() defaultValue) {
    return switch (this) {
      Success<T>(data: final data) => data,
      Failure<T>() => defaultValue(),
    };
  }

  T? getOrNull() {
    return switch (this) {
      Success<T>(data: final data) => data,
      Failure<T>() => null,
    };
  }

  Result<T> recover(T Function(TangentSDKException error) recovery) {
    return switch (this) {
      Success<T>() => this,
      Failure<T>(error: final error) => Success(recovery(error)),
    };
  }

  Result<T> recoverWith(Result<T> Function(TangentSDKException error) recovery) {
    return switch (this) {
      Success<T>() => this,
      Failure<T>(error: final error) => recovery(error),
    };
  }

  Result<T> mapError(TangentSDKException Function(TangentSDKException error) transform) {
    return switch (this) {
      Success<T>() => this,
      Failure<T>(error: final error) => Failure(transform(error)),
    };
  }

  void forEach(void Function(T data) action) {
    if (this is Success<T>) {
      action((this as Success<T>).data);
    }
  }

  bool any(bool Function(T data) predicate) {
    return switch (this) {
      Success<T>(data: final data) => predicate(data),
      Failure<T>() => false,
    };
  }

  Result<List<T>> toList() {
    return switch (this) {
      Success<T>(data: final data) => Success([data]),
      Failure<T>(error: final error) => Failure(error),
    };
  }
}

@immutable
final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Success<T> && data == other.data);
  }

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

@immutable
final class Failure<T> extends Result<T> {
  const Failure(this.error);

  final TangentSDKException error;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Failure<T> && error == other.error);
  }

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}

extension FutureResultExtension<T> on Future<Result<T>> {
  Future<R> foldAsync<R>({
    required R Function(T data) onSuccess,
    required R Function(TangentSDKException error) onFailure,
  }) async {
    final result = await this;
    return result.fold(onSuccess: onSuccess, onFailure: onFailure);
  }

  Future<Result<R>> mapAsync<R>(R Function(T data) transform) async {
    final result = await this;
    return result.map(transform);
  }

  Future<Result<R>> flatMapAsync<R>(
    Future<Result<R>> Function(T data) transform,
  ) async {
    final result = await this;
    return switch (result) {
      Success<T>(data: final data) => await transform(data),
      Failure<T>(error: final error) => Failure(error),
    };
  }

  Future<Result<T>> mapErrorAsync(
    TangentSDKException Function(TangentSDKException error) transform,
  ) async {
    final result = await this;
    return result.mapError(transform);
  }
}

Result<T> resultOf<T>(T Function() computation) {
  try {
    return Success(computation());
  } on TangentSDKException catch (e) {
    return Failure(e);
  } catch (e) {
    return Failure(ServiceOperationException('Unexpected error', e));
  }
}

Future<Result<T>> resultOfAsync<T>(Future<T> Function() computation) async {
  try {
    final result = await computation();
    return Success(result);
  } on TangentSDKException catch (e) {
    return Failure(e);
  } catch (e) {
    return Failure(ServiceOperationException('Unexpected error', e));
  }
}

Result<List<T>> combineResults<T>(List<Result<T>> results) {
  final List<T> successValues = [];
  
  for (final result in results) {
    switch (result) {
      case Success<T>(data: final data):
        successValues.add(data);
        break;
      case Failure<T>(error: final error):
        return Failure(error);
    }
  }
  
  return Success(successValues);
}

Result<(T1, T2)> combine2Results<T1, T2>(Result<T1> result1, Result<T2> result2) {
  return switch ((result1, result2)) {
    (Success<T1>(data: final data1), Success<T2>(data: final data2)) => Success((data1, data2)),
    (Failure<T1>(error: final error), _) => Failure(error),
    (_, Failure<T2>(error: final error)) => Failure(error),
  };
}

Result<(T1, T2, T3)> combine3Results<T1, T2, T3>(
  Result<T1> result1, 
  Result<T2> result2, 
  Result<T3> result3
) {
  return switch ((result1, result2, result3)) {
    (Success<T1>(data: final data1), Success<T2>(data: final data2), Success<T3>(data: final data3)) => 
      Success((data1, data2, data3)),
    (Failure<T1>(error: final error), _, _) => Failure(error),
    (_, Failure<T2>(error: final error), _) => Failure(error),
    (_, _, Failure<T3>(error: final error)) => Failure(error),
  };
}

Future<Result<List<T>>> combineAsyncResults<T>(List<Future<Result<T>>> futures) async {
  final results = await Future.wait(futures);
  return combineResults(results);
}

Result<T> resultOfNullable<T>(T? value, TangentSDKException error) {
  return value != null ? Success(value) : Failure(error);
}