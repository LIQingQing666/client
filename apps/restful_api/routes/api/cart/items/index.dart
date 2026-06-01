import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/data/database.dart';
import '../../../../lib/middleware/auth.dart' show requireUser;

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  final authUser = requireUser(context);

  final body = await context.request.body();
  final Map<String, dynamic> data;
  try {
    data = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: errorBody(400, '请求体格式错误'));
  }

  final productId = data['productId'] as String?;
  final quantity = data['quantity'] as int? ?? 1;
  final spec = data['spec'] as Map<String, dynamic>?;

  if (productId == null || productId.isEmpty) {
    return Response.json(statusCode: 400, body: errorBody(400, '商品ID不能为空'));
  }

  final product = findProductById(productId);
  if (product == null) {
    return Response.json(statusCode: 404, body: errorBody(404, '商品不存在'));
  }

  if (quantity < 1) {
    return Response.json(statusCode: 400, body: errorBody(400, '数量必须大于0'));
  }

  final cart = getCartForUser(authUser.userId);

  // If the same product+spec already exists, increment quantity
  final existingIndex = cart.indexWhere((item) {
    if (item['productId'] != productId) return false;
    final itemSpec = item['spec'] as Map<String, dynamic>?;
    if (spec == null && itemSpec == null) return true;
    if (spec == null || itemSpec == null) return false;
    return _specEqual(spec, itemSpec);
  });

  if (existingIndex >= 0) {
    cart[existingIndex]['quantity'] = (cart[existingIndex]['quantity'] as int) + quantity;
  } else {
    cart.add({
      'itemId': nextCartItemId(),
      'productId': productId,
      'userId': authUser.userId,
      'quantity': quantity,
      'spec': spec,
      'selected': true,
    });
  }
  persist();

  final enrichedItems = cart.map((item) {
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

  return Response.json(
    body: successBody({'items': enrichedItems}, message: '已加入购物车'),
  );
}

bool _specEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (a[key] != b[key]) return false;
  }
  return true;
}