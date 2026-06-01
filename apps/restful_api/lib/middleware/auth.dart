import 'package:dart_frog/dart_frog.dart';

import '../data/database.dart' hide successBody, errorBody;

/// Extracts the user from the Authorization header and provides it via context.
///
/// Use [requireUser] to get the authenticated user from a handler.
/// Returns null if no valid token is provided (public endpoints should not fail).
Handler authMiddleware(Handler handler) {
  return (context) async {
    final token = extractToken(context.request);
    final user = findUserByToken(token);

    final ctx = user != null ? context.provide<User>(() => User.fromMap(user)) : context;

    return handler(ctx);
  };
}

/// Throws a 401 Response if the user is not authenticated.
/// Returns the authenticated user if present.
User requireUser(RequestContext context) {
  try {
    return context.read<User>();
  } catch (_) {
    throw unauthorizedResponse();
  }
}

Response unauthorizedResponse() {
  return Response.json(
    statusCode: 401,
    body: {
      'code': 401,
      'message': '请先登录',
      'data': null,
    },
  );
}

String? extractToken(Request request) {
  final header = request.headers['Authorization'];
  if (header == null || !header.startsWith('Bearer ')) return null;
  return header.substring(7).trim();
}

class User {
  final String userId;
  final String username;
  final String nickname;
  final String avatar;
  final String token;

  const User({
    required this.userId,
    required this.username,
    required this.nickname,
    required this.avatar,
    required this.token,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userId: map['userId'] as String,
      username: map['username'] as String,
      nickname: map['nickname'] as String,
      avatar: map['avatar'] as String,
      token: map['token'] as String,
    );
  }
}