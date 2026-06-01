import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import '../../../lib/data/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  final body = await context.request.body();
  final Map<String, dynamic> data;
  try {
    data = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: errorBody(400, '请求体格式错误'));
  }

  final username = data['username'] as String?;
  final password = data['password'] as String?;

  if (username == null || username.isEmpty) {
    return Response.json(statusCode: 400, body: errorBody(400, '用户名不能为空'));
  }
  if (password == null || password.isEmpty) {
    return Response.json(statusCode: 400, body: errorBody(400, '密码不能为空'));
  }

  final user = findUserByUsername(username);
  if (user == null) {
    return Response.json(statusCode: 401, body: errorBody(401, '用户名或密码错误'));
  }
  if (user['password'] != password) {
    return Response.json(statusCode: 401, body: errorBody(401, '用户名或密码错误'));
  }

  return Response.json(
    body: successBody({
      'token': user['token'],
      'user': sanitizeUser(user),
    }, message: '登录成功'),
  );
}