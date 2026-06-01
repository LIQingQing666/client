import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/data/database.dart';

Future<Response> onRequest(RequestContext context, String videoId) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  final video = findVideoById(videoId);
  if (video == null) {
    return Response.json(statusCode: 404, body: errorBody(404, '视频不存在'));
  }

  // Associate products — in a real app this would be a join table.
  // Here we pick related products tagged for this video or default to the first 3.
  final relatedProducts = products
      .where((p) => p['videoId'] == videoId)
      .toList();

  final result = Map<String, dynamic>.from(video);
  result['relatedProducts'] = relatedProducts.isEmpty
      ? products.take(3).map((p) => {
            'productId': p['productId'],
            'title': p['title'],
            'price': p['price'],
            'image': (p['images'] as List).first,
          }).toList()
      : relatedProducts.map((p) => {
            'productId': p['productId'],
            'title': p['title'],
            'price': p['price'],
            'image': (p['images'] as List).first,
          }).toList();

  return Response.json(body: successBody(result));
}