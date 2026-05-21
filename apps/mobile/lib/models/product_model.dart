final class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.coverUrl,
    required this.images,
    required this.price,
    required this.originalPrice,
    required this.stock,
    required this.sales,
    required this.category,
    required this.tags,
    required this.specs,
    required this.videoId,
    required this.aiSalesPoint,
    this.highlightTime = 0,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawSpecs = (json['specs'] as List<dynamic>?) ?? [];
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      coverUrl: (json['cover_url'] as String?) ?? '',
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      price: (json['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (json['original_price'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      sales: (json['sales'] as num?)?.toInt() ?? 0,
      category: (json['category'] as String?) ?? '',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      specs: rawSpecs
          .map((e) => ProductSpec.fromJson(e as Map<String, dynamic>))
          .toList(),
      videoId: (json['video_id'] as String?) ?? '',
      aiSalesPoint: (json['ai_sales_point'] as String?) ?? '',
      highlightTime: (json['highlight_time'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final String description;
  final String coverUrl;
  final List<String> images;
  final double price;
  final double originalPrice;
  final int stock;
  final int sales;
  final String category;
  final List<String> tags;
  final List<ProductSpec> specs;
  final String videoId;
  final String aiSalesPoint;
  final int highlightTime;

  bool get hasDiscount => originalPrice > price;

  String get discountPercent {
    if (!hasDiscount) {
      return '';
    }
    final pct = ((1 - price / originalPrice) * 100).round();
    return '-$pct%';
  }
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
