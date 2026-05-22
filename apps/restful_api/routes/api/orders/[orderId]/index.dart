import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/data/database.dart';
import '../../../../lib/middleware/auth.dart' show requireUser;

Future<Response> onRequest(RequestContext context, String orderId) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  final authUser = requireUser(context);

  final order = findOrderById(orderId);
  if (order == null) {
    return Response.json(statusCode: 404, body: errorBody(404, '订单不存在'));
  }

  if (order['userId'] != authUser.userId) {
    return Response.json(statusCode: 403, body: errorBody(403, '无权查看此订单'));
  }

  return Response.json(body: successBody(order));
}