import '../models/cart_model.dart';
import '../models/order_model.dart';
import 'api_exception.dart';
import 'dio_client.dart';

final class DirectOrderRequest {
  const DirectOrderRequest({
    required this.productId,
    this.quantity = 1,
    this.spec = '',
    this.address,
  });

  final String productId;
  final int quantity;
  final String spec;
  final OrderAddress? address;

  Map<String, dynamic> toJson(String userId) => {
    'user_id': userId,
    'product_id': productId,
    'quantity': quantity,
    'spec': spec,
    if (address != null) 'address': address!.toJson(),
  };
}

final class OrderApi {
  const OrderApi({required this.client});

  final DioClient client;

  /// 直接下单（不经过购物车，从视频/直播立即购买）
  Future<CreateOrderResult> createDirectOrder({
    required String userId,
    required DirectOrderRequest request,
  }) async {
    final response = await client.post<Map<String, dynamic>>(
      '/orders/direct',
      data: request.toJson(userId),
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return CreateOrderResult.fromJson(data);
  }

  Future<CreateOrderResult> createOrder({
    required String userId,
    required List<CartItemModel> items,
    OrderAddress? address,
    String? couponId,
    double? payAmount,
    Map<String, double>? itemDiscounts,
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
          if (itemDiscounts != null && itemDiscounts.containsKey(item.id))
            'coupon_discount': itemDiscounts[item.id],
        }).toList(),
        'address': address?.toJson() ?? {},
        if (couponId != null) 'coupon_id': couponId,
        if (payAmount != null) 'pay_amount': payAmount,
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

  Future<Map<String, dynamic>> payOrder(String orderId, {String paymentMethod = 'wechat'}) async {
    final response = await client.post<Map<String, dynamic>>(
      '/orders/$orderId/pay',
      data: <String, dynamic>{
        'payment_method': paymentMethod,
      },
    );
    return response.data!['data'] as Map<String, dynamic>;
  }

  /// 退货退款（仅已完成订单可操作）
  Future<Map<String, dynamic>> refundOrder({
    required String orderId,
    required String productId,
    required String reason,
  }) async {
    final response = await client.post<Map<String, dynamic>>(
      '/orders/$orderId/refund',
      data: <String, dynamic>{
        'product_id': productId,
        'reason': reason,
      },
    );
    final body = response.data!;
    if (body['code'] != 0) {
      throw BusinessException(
        body['message'] as String? ?? '退款失败',
        statusCode: 200,
        data: body,
      );
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// 确认收货（仅已支付订单可操作）
  Future<OrderModel> confirmOrder(String orderId) async {
    final response = await client.post<Map<String, dynamic>>(
      '/orders/$orderId/confirm',
      data: <String, dynamic>{},
    );
    final body = response.data!;
    if (body['code'] != 0) {
      throw BusinessException(
        body['message'] as String? ?? '确认收货失败',
        statusCode: 200,
        data: body,
      );
    }
    return OrderModel.fromJson(
      body['data'] as Map<String, dynamic>,
    );
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
