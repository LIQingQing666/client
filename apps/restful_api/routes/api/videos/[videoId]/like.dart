import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/data/database.dart';
import '../../../../lib/middleware/auth.dart' show requireUser;

Future<Response> onRequest(RequestContext context, String videoId) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  final authUser = requireUser(context);

  final video = findVideoById(videoId);
  if (video == null) {
    return Response.json(statusCode: 404, body: errorBody(404, '视频不存在'));
  }

  final likes = videoLikes.putIfAbsent(videoId, () => <String>{});
  final liked = likes.contains(authUser.userId);

  if (liked) {
    likes.remove(authUser.userId);
    video['likeCount'] = (video['likeCount'] as int) - 1;
  } else {
    likes.add(authUser.userId);
    video['likeCount'] = (video['likeCount'] as int) + 1;
  }
  persist();

  return Response.json(
    body: successBody({
      'liked': !liked,
      'likeCount': video['likeCount'],
    }, message: liked ? '已取消点赞' : '点赞成功'),
  );
}