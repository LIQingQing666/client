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
  final nickname = data['nickname'] as String?;

  if (username == null || username.isEmpty) {
    return Response.json(statusCode: 400, body: errorBody(400, '用户名不能为空'));
  }
  if (password == null || password.isEmpty) {
    return Response.json(statusCode: 400, body: errorBody(400, '密码不能为空'));
  }

  if (findUserByUsername(username) != null) {
    return Response.json(statusCode: 400, body: errorBody(400, '用户名已存在'));
  }

  final userId = 'u${users.length + 1}';
  final token = generateToken(userId);
  final newUser = {
    'userId': userId,
    'username': username,
    'password': password,
    'nickname': nickname ?? username,
    'avatar': 'https://example.com/avatars/default.png',
    'token': token,
  };
  users.add(newUser);
  persist();

  return Response.json(
    body: successBody({
      'userId': userId,
      'token': token,
      'nickname': newUser['nickname'],
    }, message: '注册成功'),
  );
}
