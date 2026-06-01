import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import '../../../lib/data/database.dart';
import '../../../lib/middleware/auth.dart' show requireUser;

Future<Response> onRequest(RequestContext context) async {
  final authUser = requireUser(context);

  switch (context.request.method) {
    case HttpMethod.get:
      return _listOrders(context, authUser.userId);
    case HttpMethod.post:
      return _createOrder(context, authUser.userId);
    default:
      return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }
}

Future<Response> _listOrders(RequestContext context, String userId) async {
  final page = int.tryParse(context.request.uri.queryParameters['page'] ?? '1') ?? 1;
  final pageSize = int.tryParse(context.request.uri.queryParameters['pageSize'] ?? '10') ?? 10;
  final status = context.request.uri.queryParameters['status'] ?? '';

  var userOrders = orders.where((o) => o['userId'] == userId).toList();

  if (status.isNotEmpty) {
    userOrders = userOrders.where((o) => o['status'] == status).toList();
  }

  userOrders.sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));

  final result = paginate(userOrders, page, pageSize);
  return Response.json(body: successBody(result));
}

Future<Response> _createOrder(RequestContext context, String userId) async {
  final body = await context.request.body();
  final Map<String, dynamic> data;
  try {
    data = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: errorBody(400, '请求体格式错误'));
  }

  final addressId = data['addressId'] as String?;
  final cartItemIds = (data['cartItemIds'] as List<dynamic>?)?.cast<String>();

  if (addressId == null || addressId.isEmpty) {
    return Response.json(statusCode: 400, body: errorBody(400, '收货地址不能为空'));
  }

  final cart = getCartForUser(userId);

  List<Map<String, dynamic>> selectedItems;
  if (cartItemIds != null && cartItemIds.isNotEmpty) {
    selectedItems = cart.where((item) => cartItemIds.contains(item['itemId'])).toList();
  } else {
    selectedItems = cart.where((item) => item['selected'] == true).toList();
  }

  if (selectedItems.isEmpty) {
    return Response.json(statusCode: 400, body: errorBody(400, '请选择要购买的商品'));
  }

  double totalAmount = 0;
  final orderItems = <Map<String, dynamic>>[];

  for (final cartItem in selectedItems) {
    final product = findProductById(cartItem['productId'] as String);
    if (product == null) continue;

    final price = product['price'] as double;
    final quantity = cartItem['quantity'] as int;
    totalAmount += price * quantity;

    orderItems.add({
      'productId': product['productId'],
      'title': product['title'],
      'image': (product['images'] as List).first,
      'price': price,
      'quantity': quantity,
      'spec': cartItem['spec'],
    });
  }

  final order = {
    'orderId': nextOrderId(),
    'userId': userId,
    'items': orderItems,
    'totalAmount': totalAmount,
    'paidAmount': totalAmount,
    'status': 'pending_payment',
    'addressId': addressId,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'paidAt': null,
  };

  orders.insert(0, order);

  // Remove purchased items from cart
  cart.removeWhere((item) => selectedItems.contains(item));
  persist();

  return Response.json(
    body: successBody(order, message: '订单创建成功'),
  );
}