import 'dio_client.dart';

final class AdminApi {
  const AdminApi({required this.client});

  final DioClient client;

  Future<DashboardData> getDashboard() async {
    final response = await client.get<Map<String, dynamic>>('/admin/dashboard');
    final data = response.data!['data'] as Map<String, dynamic>;
    return DashboardData.fromJson(data);
  }
}

final class DashboardData {
  const DashboardData({
    required this.funnel,
    required this.topProducts,
    required this.videoGmv,
    required this.categories,
    required this.totalGmv,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final rawProducts = (json['top_products'] as List<dynamic>?) ?? [];
    final rawVideoGmv = (json['video_gmv'] as List<dynamic>?) ?? [];
    final rawCategories = (json['categories'] as List<dynamic>?) ?? [];
    return DashboardData(
      funnel: FunnelData.fromJson(json['funnel'] as Map<String, dynamic>),
      topProducts: rawProducts
          .map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      videoGmv: rawVideoGmv
          .map((e) => VideoGmvItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: rawCategories
          .map((e) => CategoryStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalGmv: (json['total_gmv'] as num?)?.toDouble() ?? 0,
    );
  }

  final FunnelData funnel;
  final List<TopProduct> topProducts;
  final List<VideoGmvItem> videoGmv;
  final List<CategoryStat> categories;
  final double totalGmv;
}

final class FunnelData {
  const FunnelData({
    required this.impressions,
    required this.productClicks,
    required this.addToCart,
    required this.orders,
    required this.rates,
  });

  factory FunnelData.fromJson(Map<String, dynamic> json) {
    return FunnelData(
      impressions: (json['impressions'] as num?)?.toInt() ?? 0,
      productClicks: (json['product_clicks'] as num?)?.toInt() ?? 0,
      addToCart: (json['add_to_cart'] as num?)?.toInt() ?? 0,
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      rates: ConversionRates.fromJson(json['rates'] as Map<String, dynamic>? ?? {}),
    );
  }

  final int impressions;
  final int productClicks;
  final int addToCart;
  final int orders;
  final ConversionRates rates;
}

final class ConversionRates {
  const ConversionRates({
    required this.clickThrough,
    required this.cartConversion,
    required this.orderConversion,
  });

  factory ConversionRates.fromJson(Map<String, dynamic> json) {
    return ConversionRates(
      clickThrough: (json['click_through'] as num?)?.toDouble() ?? 0,
      cartConversion: (json['cart_conversion'] as num?)?.toDouble() ?? 0,
      orderConversion: (json['order_conversion'] as num?)?.toDouble() ?? 0,
    );
  }

  final double clickThrough;
  final double cartConversion;
  final double orderConversion;
}

final class TopProduct {
  const TopProduct({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.price,
    required this.sales,
    required this.category,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      coverUrl: (json['cover_url'] as String?) ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      sales: (json['sales'] as num?)?.toInt() ?? 0,
      category: (json['category'] as String?) ?? '',
    );
  }

  final String id;
  final String name;
  final String coverUrl;
  final double price;
  final int sales;
  final String category;
}

final class VideoGmvItem {
  const VideoGmvItem({
    required this.id,
    required this.title,
    required this.authorName,
    required this.playCount,
    required this.gmv,
    required this.productSales,
  });

  factory VideoGmvItem.fromJson(Map<String, dynamic> json) {
    return VideoGmvItem(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      authorName: (json['author_name'] as String?) ?? '',
      playCount: (json['play_count'] as num?)?.toInt() ?? 0,
      gmv: (json['gmv'] as num?)?.toDouble() ?? 0,
      productSales: (json['product_sales'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String title;
  final String authorName;
  final int playCount;
  final double gmv;
  final int productSales;
}

final class CategoryStat {
  const CategoryStat({
    required this.category,
    required this.count,
    required this.totalSales,
  });

  factory CategoryStat.fromJson(Map<String, dynamic> json) {
    return CategoryStat(
      category: (json['category'] as String?) ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      totalSales: (json['total_sales'] as num?)?.toInt() ?? 0,
    );
  }

  final String category;
  final int count;
  final int totalSales;
}
