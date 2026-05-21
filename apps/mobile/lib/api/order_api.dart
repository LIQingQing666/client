import '../models/cart_model.dart';
import '../models/order_model.dart';
import 'dio_client.dart';

final class OrderApi {
  const OrderApi({required this.client});

  final DioClient client;

  Future<CreateOrderResult> createOrder({
    required String userId,
    required List<CartItemModel> items,
    OrderAddress? address,
    String? couponId,
  }) async {
    final response = await client.post<Map<String, dynamic>>(
      '/orders',
      data: <String, dynamic>{
        'user_id': userId,
        'items': items.map((item) => <String, dynamic>{
          'product_id': item.productId,
          'spec': item.spec,
          'quantity': item.quantity,
          'cart_item_id': item.id,
        }).toList(),
        'address': address?.toJson() ?? {},
        if (couponId != null) 'coupon_id': couponId,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return CreateOrderResult.fromJson(data);
  }

  Future<OrderListResponse> getOrders({
    required String userId,
    String? status,
    int page = 1,
    int pageSize = 10,
  }) async {
    final query = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (status != null) {
      query['status'] = status;
    }

    final response = await client.get<Map<String, dynamic>>(
      '/orders/$userId',
      queryParameters: query,
    );
    return OrderListResponse.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  Future<OrderModel> getOrderDetail(String orderId) async {
    final response = await client.get<Map<String, dynamic>>(
      '/orders/detail/$orderId',
    );
    return OrderModel.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  Future<String> payOrder(String orderId) async {
    final response = await client.post<Map<String, dynamic>>(
      '/orders/$orderId/pay',
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['status'] as String;
  }
}

final class CreateOrderResult {
  const CreateOrderResult({
    required this.id,
    required this.totalAmount,
    required this.discountAmount,
    required this.payAmount,
    required this.status,
  });

  factory CreateOrderResult.fromJson(Map<String, dynamic> json) {
    return CreateOrderResult(
      id: json['id'] as String,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      payAmount: (json['pay_amount'] as num?)?.toDouble() ?? 0,
      status: (json['status'] as String?) ?? 'pending',
    );
  }

  final String id;
  final double totalAmount;
  final double discountAmount;
  final double payAmount;
  final String status;
}

final class OrderListResponse {
  const OrderListResponse({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory OrderListResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['list'] as List<dynamic>;
    return OrderListResponse(
      list: rawList
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
      hasMore: json['has_more'] as bool,
    );
  }

  final List<OrderModel> list;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;
}
