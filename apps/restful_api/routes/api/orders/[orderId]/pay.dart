import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/data/database.dart';
import '../../../../lib/middleware/auth.dart' show requireUser;

Future<Response> onRequest(RequestContext context, String orderId) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  final authUser = requireUser(context);

  final order = findOrderById(orderId);
  if (order == null) {
    return Response.json(statusCode: 404, body: errorBody(404, '订单不存在'));
  }

  if (order['userId'] != authUser.userId) {
    return Response.json(statusCode: 403, body: errorBody(403, '无权操作此订单'));
  }

  if (order['status'] != 'pending_payment') {
    return Response.json(statusCode: 400, body: errorBody(400, '当前订单状态不可支付'));
  }

  order['status'] = 'pending_delivery';
  order['paidAt'] = DateTime.now().toUtc().toIso8601String();
  persist();

  return Response.json(
    body: successBody(order, message: '支付成功'),
  );
}