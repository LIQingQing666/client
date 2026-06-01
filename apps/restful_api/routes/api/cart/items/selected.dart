import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/data/database.dart';
import '../../../../lib/middleware/auth.dart' show requireUser;

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.put) {
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

  final itemIds = (data['itemIds'] as List<dynamic>?)?.cast<String>() ?? <String>[];
  final selected = data['selected'] as bool? ?? true;

  final cart = getCartForUser(authUser.userId);

  if (itemIds.isEmpty) {
    // Toggle all items
    for (final item in cart) {
      item['selected'] = selected;
    }
  } else {
    for (final itemId in itemIds) {
      final item = findCartItem(authUser.userId, itemId);
      if (item != null) {
        item['selected'] = selected;
      }
    }
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
    body: successBody({'items': enrichedItems}, message: '已更新'),
  );
}