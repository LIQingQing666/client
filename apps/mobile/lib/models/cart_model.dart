final class CartItemModel {
  const CartItemModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productName,
    required this.productCover,
    required this.productPrice,
    required this.productOriginalPrice,
    required this.productStock,
    required this.spec,
    required this.quantity,
    required this.selected,
    required this.productSpecs,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final rawSpecs = (json['product_specs'] as List<dynamic>?) ?? [];
    return CartItemModel(
      id: json['id'] as String,
      userId: (json['user_id'] as String?) ?? '',
      productId: (json['product_id'] as String?) ?? '',
      productName: (json['product_name'] as String?) ?? '',
      productCover: (json['product_cover'] as String?) ?? '',
      productPrice: (json['product_price'] as num?)?.toDouble() ?? 0,
      productOriginalPrice: (json['product_original_price'] as num?)?.toDouble() ?? 0,
      productStock: (json['product_stock'] as num?)?.toInt() ?? 0,
      spec: (json['spec'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      selected: (json['selected'] as num?)?.toInt() == 1,
      productSpecs: rawSpecs
          .map((e) => ProductSpec.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String userId;
  final String productId;
  final String productName;
  final String productCover;
  final double productPrice;
  final double productOriginalPrice;
  final int productStock;
  final String spec;
  final int quantity;
  final bool selected;
  final List<ProductSpec> productSpecs;
}

final class ProductSpec {
  const ProductSpec({required this.name, required this.values});

  factory ProductSpec.fromJson(Map<String, dynamic> json) {
    final rawValues = (json['values'] as List<dynamic>?) ?? [];
    return ProductSpec(
      name: json['name'] as String,
      values: rawValues.cast<String>(),
    );
  }

  final String name;
  final List<String> values;
}
