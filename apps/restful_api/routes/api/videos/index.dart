import 'package:dart_frog/dart_frog.dart';

import '../../../lib/data/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  final page = int.tryParse(context.request.uri.queryParameters['page'] ?? '1') ?? 1;
  final pageSize = int.tryParse(context.request.uri.queryParameters['pageSize'] ?? '10') ?? 10;

  final result = paginate(videos, page, pageSize);

  return Response.json(body: successBody(result));
}