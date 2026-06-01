/// A labeled video segment (e.g. "材质介绍" starting at 15s).
final class ProductSegment {
  const ProductSegment({
    required this.label,
    required this.startTime,
    this.endTime = 0,
  });

  factory ProductSegment.fromJson(Map<String, dynamic> json) {
    return ProductSegment(
      label: (json['label'] as String?) ?? '',
      startTime: (json['start_time'] as num?)?.toInt() ?? 0,
      endTime: (json['end_time'] as num?)?.toInt() ?? 0,
    );
  }

  final String label;
  final int startTime;
  final int endTime; // 0 means no limit
}

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
    this.segments = const [],
    this.status = 'active',
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawSpecs = (json['specs'] as List<dynamic>?) ?? [];
    final rawSegments = (json['segments'] as List<dynamic>?) ?? [];
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
      segments: rawSegments
          .map((e) => ProductSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: (json['status'] as String?) ?? 'active',
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
  final List<ProductSegment> segments;
  final String status;

  bool get isActive => status == 'active';

  /// Effective seek time: prefer the first segment's startTime if available,
  /// otherwise fall back to highlightTime.
  int get effectiveSeekTime {
    if (segments.isNotEmpty) return segments.first.startTime;
    return highlightTime;
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    String? coverUrl,
    List<String>? images,
    double? price,
    double? originalPrice,
    int? stock,
    int? sales,
    String? category,
    List<String>? tags,
    List<ProductSpec>? specs,
    String? videoId,
    String? aiSalesPoint,
    int? highlightTime,
    List<ProductSegment>? segments,
    String? status,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      images: images ?? this.images,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      stock: stock ?? this.stock,
      sales: sales ?? this.sales,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      specs: specs ?? this.specs,
      videoId: videoId ?? this.videoId,
      aiSalesPoint: aiSalesPoint ?? this.aiSalesPoint,
      highlightTime: highlightTime ?? this.highlightTime,
      segments: segments ?? this.segments,
      status: status ?? this.status,
    );
  }

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
