import 'package:dart_frog/dart_frog.dart';

import '../../../lib/data/database.dart';

Future<Response> onRequest(RequestContext context, String productId) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  final product = findProductById(productId);
  if (product == null) {
    return Response.json(statusCode: 404, body: errorBody(404, '商品不存在'));
  }

  final productComments = comments
      .where((c) => c['targetType'] == 'product' && c['targetId'] == productId)
      .toList();

  final enrichedComments = productComments.map((c) {
    final user = findUserById(c['userId'] as String);
    return {
      ...c,
      'user': user != null
          ? {
              'userId': user['userId'],
              'nickname': user['nickname'],
              'avatar': user['avatar'],
            }
          : null,
    };
  }).toList();

  return Response.json(
    body: successBody({
      ...product,
      'comments': enrichedComments,
    }),
  );
}