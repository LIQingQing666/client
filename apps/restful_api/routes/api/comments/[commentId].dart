import 'package:dart_frog/dart_frog.dart';

import '../../../lib/data/database.dart';
import '../../../lib/middleware/auth.dart' show requireUser;

Future<Response> onRequest(RequestContext context, String commentId) async {
  if (context.request.method != HttpMethod.delete) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  final authUser = requireUser(context);

  final index = comments.indexWhere((c) => c['commentId'] == commentId);
  if (index < 0) {
    return Response.json(statusCode: 404, body: errorBody(404, '评论不存在'));
  }

  final comment = comments[index];
  if (comment['userId'] != authUser.userId) {
    return Response.json(statusCode: 403, body: errorBody(403, '无权删除他人评论'));
  }

  final targetType = comment['targetType'] as String;
  final targetId = comment['targetId'] as String;

  comments.removeAt(index);
  persist();

  // Update comment count on video
  if (targetType == 'video') {
    final video = findVideoById(targetId);
    if (video != null) {
      video['commentCount'] = ((video['commentCount'] as int) - 1).clamp(0, 999999);
    }
  }

  return Response.json(body: successBody(null, message: '评论已删除'));
}