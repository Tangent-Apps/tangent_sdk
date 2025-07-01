import 'package:meta/meta.dart';

@immutable
class Purchase {
  final String productId;
  final String transactionId;
  final String? originalTransactionId;
  final DateTime expirationDate;
  final DateTime purchaseDate;

  final Map<String, dynamic>? metadata;

  const Purchase({
    required this.productId,
    required this.transactionId,
    required this.purchaseDate,
    required this.expirationDate,
    this.originalTransactionId,
    this.metadata,
  });
}
