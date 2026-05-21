import '../models/product_model.dart';
import 'dio_client.dart';

final class ProductApi {
  const ProductApi({required this.client});

  final DioClient client;

  Future<ProductListResponse> getProducts({
    int page = 1,
    int pageSize = 10,
    String? category,
    String? keyword,
  }) async {
    final query = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (category != null) {
      query['category'] = category;
    }
    if (keyword != null) {
      query['keyword'] = keyword;
    }

    final response = await client.get<Map<String, dynamic>>(
      '/products',
      queryParameters: query,
    );
    return ProductListResponse.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  Future<ProductDetailResponse> getProductDetail(String id) async {
    final response = await client.get<Map<String, dynamic>>(
      '/products/$id',
    );
    return ProductDetailResponse.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  Future<List<ProductModel>> getRecommend({
    String? userId,
    int limit = 6,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (userId != null) {
      query['user_id'] = userId;
    }

    final response = await client.get<Map<String, dynamic>>(
      '/products/recommend',
      queryParameters: query,
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final list = (data['list'] as List<dynamic>)
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<String> getAiSalesPoint(String productId) async {
    final response = await client.get<Map<String, dynamic>>(
      '/products/$productId/ai-sales-point',
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['sales_point'] as String;
  }
}

final class ProductListResponse {
  const ProductListResponse({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory ProductListResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['list'] as List<dynamic>;
    return ProductListResponse(
      list: rawList
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
      hasMore: json['has_more'] as bool,
    );
  }

  final List<ProductModel> list;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;
}

final class ProductDetailResponse {
  const ProductDetailResponse({
    required this.product,
    required this.comments,
    required this.relatedProducts,
    this.video,
  });

  factory ProductDetailResponse.fromJson(Map<String, dynamic> json) {
    final rawComments = (json['comments'] as List<dynamic>?) ?? [];
    final rawRelated = (json['related_products'] as List<dynamic>?) ?? [];
    return ProductDetailResponse(
      product: ProductModel.fromJson(json),
      comments: rawComments.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      relatedProducts: rawRelated
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      video: json['video'] as Map<String, dynamic>?,
    );
  }

  final ProductModel product;
  final List<Map<String, dynamic>> comments;
  final List<ProductModel> relatedProducts;
  final Map<String, dynamic>? video;
}
