import 'package:meta/meta.dart';

@immutable
class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final String priceString;
  final String currencyCode;
  final String? introductoryPrice;
  final Map<String, dynamic>? metadata;
  final dynamic storeProduct;
  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currencyCode,
    required this.storeProduct,
    required this.priceString,
    this.introductoryPrice,
    this.metadata,
  });
}
