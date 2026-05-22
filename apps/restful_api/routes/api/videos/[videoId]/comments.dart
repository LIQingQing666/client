import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/data/database.dart';

Future<Response> onRequest(RequestContext context, String videoId) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  final page = int.tryParse(context.request.uri.queryParameters['page'] ?? '1') ?? 1;
  final pageSize = int.tryParse(context.request.uri.queryParameters['pageSize'] ?? '10') ?? 10;

  final videoComments = comments
      .where((c) => c['targetType'] == 'video' && c['targetId'] == videoId)
      .toList();

  videoComments.sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));

  final result = paginate(videoComments, page, pageSize);

  // Attach user info to each comment
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