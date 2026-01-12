import 'package:meta/meta.dart';
import 'package:tangent_sdk/src/core/types/result.dart';

@immutable
abstract class AppCheckService {
  const AppCheckService();

  Future<Result<void>> activate();
}
