import 'package:meta/meta.dart';

@immutable
class Entitlement {
  /// The unique identifier for this entitlement
  final String identifier;

  /// Whether this entitlement is currently active
  final bool isActive;

  const Entitlement({
    required this.identifier,
    required this.isActive,
  });

  @override
  String toString() {
    return 'Entitlement(identifier: $identifier, isActive: $isActive)';
  }
}
