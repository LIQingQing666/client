import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/data/database.dart';
import '../../../../lib/middleware/auth.dart' show requireUser;

Future<Response> onRequest(RequestContext context, String itemId) async {
  final authUser = requireUser(context);

  switch (context.request.method) {
    case HttpMethod.put:
      return _updateItem(context, authUser.userId, itemId);
    case HttpMethod.delete:
      return _deleteItem(context, authUser.userId, itemId);
    default:
      return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }
}

Future<Response> _updateItem(RequestContext context, String userId, String itemId) async {
  final body = await context.request.body();
  final Map<String, dynamic> data;
  try {
    data = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: errorBody(400, '请求体格式错误'));
  }

  final quantity = data['quantity'] as int?;
  if (quantity == null || quantity < 1) {
    return Response.json(statusCode: 400, body: errorBody(400, '数量必须大于0'));
  }

  final cart = getCartForUser(userId);
  final item = findCartItem(userId, itemId);
  if (item == null) {
    return Response.json(statusCode: 404, body: errorBody(404, '购物车项不存在'));
  }

  item['quantity'] = quantity;
  persist();

  final enrichedItems = _enrichCart(cart);
  return Response.json(
    body: successBody({'items': enrichedItems}, message: '已更新'),
  );
}

Future<Response> _deleteItem(RequestContext context, String userId, String itemId) async {
  final cart = getCartForUser(userId);
  final index = cart.indexWhere((item) => item['itemId'] == itemId);
  if (index < 0) {
    return Response.json(statusCode: 404, body: errorBody(404, '购物车项不存在'));
  }

  cart.removeAt(index);
  persist();

  final enrichedItems = _enrichCart(cart);
  return Response.json(
    body: successBody({'items': enrichedItems}, message: '已删除'),
  );
}

List<Map<String, dynamic>> _enrichCart(List<Map<String, dynamic>> cart) {
  return cart.map((item) {
    final p = findProductById(item['productId'] as String);
    return {
      ...item,
      'product': p != null
          ? {
              'productId': p['productId'],
              'title': p['title'],
              'image': (p['images'] as List).first,
              'price': p['price'],
              'stock': p['stock'],
            }
          : null,
    };
  }).toList();
}