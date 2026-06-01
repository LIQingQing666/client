import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import '../../../lib/data/database.dart';
import '../../../lib/middleware/auth.dart' show requireUser;

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _listComments(context);
    case HttpMethod.post:
      return _createComment(context);
    default:
      return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }
}

Future<Response> _listComments(RequestContext context) async {
  final page = int.tryParse(context.request.uri.queryParameters['page'] ?? '1') ?? 1;
  final pageSize = int.tryParse(context.request.uri.queryParameters['pageSize'] ?? '10') ?? 10;
  final targetType = context.request.uri.queryParameters['targetType'] ?? '';
  final targetId = context.request.uri.queryParameters['targetId'] ?? '';

  var filtered = comments;

  if (targetType.isNotEmpty) {
    filtered = filtered.where((c) => c['targetType'] == targetType).toList();
  }
  if (targetId.isNotEmpty) {
    filtered = filtered.where((c) => c['targetId'] == targetId).toList();
  }

  filtered.sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));

  final result = paginate(filtered, page, pageSize);

  final enrichedList = (result['list'] as List).map((c) {
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
      ...result,
      'list': enrichedList,
    }),
  );
}

Future<Response> _createComment(RequestContext context) async {
  final authUser = requireUser(context);

  final body = await context.request.body();
  final Map<String, dynamic> data;
  try {
    data = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: errorBody(400, '请求体格式错误'));
  }

  final targetType = data['targetType'] as String?;
  final targetId = data['targetId'] as String?;
  final content = data['content'] as String?;

  if (targetType == null || (targetType != 'video' && targetType != 'product')) {
    return Response.json(statusCode: 400, body: errorBody(400, 'targetType 必须为 video 或 product'));
  }
  if (targetId == null || targetId.isEmpty) {
    return Response.json(statusCode: 400, body: errorBody(400, 'targetId 不能为空'));
  }
  if (content == null || content.trim().isEmpty) {
    return Response.json(statusCode: 400, body: errorBody(400, '评论内容不能为空'));
  }

  final newComment = {
    'commentId': nextCommentId(),
    'userId': authUser.userId,
    'targetType': targetType,
    'targetId': targetId,
    'content': content.trim(),
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  };

  comments.add(newComment);
  persist();

  // Update comment count on video if applicable
  if (targetType == 'video') {
    final video = findVideoById(targetId);
    if (video != null) {
      video['commentCount'] = (video['commentCount'] as int) + 1;
    }
  }

  final user = findUserById(authUser.userId);

  return Response.json(
    body: successBody({
      ...newComment,
      'user': user != null
          ? {
              'userId': user['userId'],
              'nickname': user['nickname'],
              'avatar': user['avatar'],
            }
          : null,
    }, message: '评论发布成功'),
  );
}