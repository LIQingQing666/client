import 'package:dart_frog/dart_frog.dart';

import '../../../lib/data/database.dart';
import '../../../lib/middleware/auth.dart' show requireUser;

Future<Response> onRequest(RequestContext context) async {
  final authUser = requireUser(context);

  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  final cart = getCartForUser(authUser.userId);

  final enrichedItems = cart.map((item) {
    final product = findProductById(item['productId'] as String);
    return {
      ...item,
      'product': product != null
          ? {
              'productId': product['productId'],
              'title': product['title'],
              'image': (product['images'] as List).first,
              'price': product['price'],
              'stock': product['stock'],
            }
          : null,
    };
  }).toList();

  return Response.json(body: successBody({'items': enrichedItems}));
}