import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import '../../../lib/data/database.dart';
import '../../../lib/middleware/auth.dart' show requireUser;

Future<Response> onRequest(RequestContext context) async {
  final authUser = requireUser(context);

  switch (context.request.method) {
    case HttpMethod.get:
      final user = findUserById(authUser.userId);
      if (user == null) {
        return Response.json(statusCode: 404, body: errorBody(404, '用户不存在'));
      }
      return Response.json(body: successBody(sanitizeUser(user)));

    case HttpMethod.put:
      final body = await context.request.body();
      final Map<String, dynamic> data;
      try {
        data = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        return Response.json(statusCode: 400, body: errorBody(400, '请求体格式错误'));
      }

      final user = findUserById(authUser.userId);
      if (user == null) {
        return Response.json(statusCode: 404, body: errorBody(404, '用户不存在'));
      }

      if (data.containsKey('nickname') && data['nickname'] != null) {
        user['nickname'] = data['nickname'] as String;
      }
      if (data.containsKey('avatar') && data['avatar'] != null) {
        user['avatar'] = data['avatar'] as String;
      }

      return Response.json(
        body: successBody(sanitizeUser(user), message: '更新成功'),
      );

    default:
      return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }
}