import '../models/product_model.dart';
import 'package:dio/dio.dart';
import 'dio_client.dart';

final class ProductApi {
  const ProductApi({required this.client});

  final DioClient client;

  Future<ProductListResponse> getProducts({
    int page = 1,
    int pageSize = 10,
    String? category,
    String? keyword,
    String? status,
  }) async {
    final query = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (category != null) {
      query['category'] = category;
    }
    if (keyword != null) {
      query['keyword'] = keyword;
    }
    if (status != null) {
      query['status'] = status;
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

  /// 创建商品
  Future<ProductModel> createProduct(
      ProductCreateRequest request,
      ) async {
    final response = await client.post<Map<String, dynamic>>(
      '/products',
      data: request.toJson(),
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }

  /// 更新商品
  Future<ProductModel> updateProduct({
    required String id,
    required ProductCreateRequest request,
  }) async {
    final response = await client.put<Map<String, dynamic>>(
      '/products/$id',
      data: request.toJson(),
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }

  /// 删除商品
  Future<void> deleteProduct(String id) async {
    await client.delete('/products/$id');
  }

  /// 获取品类列表
  Future<List<String>> getCategories() async {
    final response = await client.get<Map<String, dynamic>>(
      '/categories',
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final list = (data['list'] as List<dynamic>)
        .map((e) => e as String)
        .toList();
    return list;
  }

  /// 生成 AI 卖点（用于新建商品时生成）
  Future<String> generateAiSalesPoint({
    required String name,
    required String description,
    required String category,
    List<String>? tags,
  }) async {
    final response = await client.post<Map<String, dynamic>>(
      '/products/ai-sales-point',
      data: {
        'name': name,
        'description': description,
        'category': category,
        if (tags != null) 'tags': tags,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['sales_point'] as String;
  }

  /// 上传商品图片
  Future<String> uploadImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await client.post<Map<String, dynamic>>(
      '/products/upload-image',
      data: formData,
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// 批量上传图片
  Future<List<String>> uploadImages(List<String> filePaths) async {
    final formData = FormData();
    for (final path in filePaths) {
      formData.files.add(
        MapEntry('files', await MultipartFile.fromFile(path)),
      );
    }
    final response = await client.post<Map<String, dynamic>>(
      '/products/upload-images',
      data: formData,
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return (data['urls'] as List<dynamic>)
        .map((e) => e as String)
        .toList();
  }

  /// 下架商品
  Future<void> deactivateProduct(String id) async {
    await client.put(
      '/products/$id',
      data: {'status': 'inactive'},
    );
  }

  /// 上架商品
  Future<void> activateProduct(String id) async {
    await client.put(
      '/products/$id',
      data: {'status': 'active'},
    );
  }

  /// 批量更新商品状态
  Future<void> batchUpdateStatus({
    required List<String> ids,
    required String status,
  }) async {
    await client.put(
      '/products/batch-status',
      data: {
        'ids': ids,
        'status': status,
      },
    );
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

/// 创建商品的请求体
final class ProductCreateRequest {
  const ProductCreateRequest({
    required this.name,
    required this.description,
    required this.price,
    required this.originalPrice,
    required this.stock,
    required this.category,
    this.tags = const [],
    required this.coverUrl,
    required this.images,
    this.aiSalesPoint,
    this.status = 'active',
  });

  final String name;
  final String description;
  final double price;
  final double originalPrice;
  final int stock;
  final String category;
  final List<String> tags;
  final String coverUrl;
  final List<String> images;
  final String? aiSalesPoint;
  final String status;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'price': price,
    'original_price': originalPrice,
    'stock': stock,
    'category': category,
    'tags': tags,
    'cover_url': coverUrl,
    'images': images,
    if (aiSalesPoint != null) 'ai_sales_point': aiSalesPoint,
    'status': status,
  };
}

/// 品类信息
final class CategoryInfo {
  const CategoryInfo({
    required this.name,
    required this.productCount,
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    return CategoryInfo(
      name: json['name'] as String,
      productCount: (json['product_count'] as num).toInt(),
    );
  }

  final String name;
  final int productCount;
}
