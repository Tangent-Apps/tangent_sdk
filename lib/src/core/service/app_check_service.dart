import 'package:meta/meta.dart';
import '../types/result.dart';

@immutable
abstract class AppCheckService {
  const AppCheckService();

  Future<Result<void>> activate();
}