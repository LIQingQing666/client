import 'package:dart_frog/dart_frog.dart';

import '../../../lib/data/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  final page = int.tryParse(context.request.uri.queryParameters['page'] ?? '1') ?? 1;
  final pageSize = int.tryParse(context.request.uri.queryParameters['pageSize'] ?? '10') ?? 10;
  final keyword = context.request.uri.queryParameters['keyword'] ?? '';
  final categoryId = context.request.uri.queryParameters['categoryId'] ?? '';

  var filtered = products;

  if (keyword.isNotEmpty) {
    filtered = filtered
        .where((p) => (p['title'] as String).toLowerCase().contains(keyword.toLowerCase()))
        .toList();
  }

  if (categoryId.isNotEmpty) {
    filtered = filtered.where((p) => p['categoryId'] == categoryId).toList();
  }

  final result = paginate(filtered, page, pageSize);

  // Return summary fields for list view
  final summaryList = (result['list'] as List).map((p) => {
        'productId': p['productId'],
        'title': p['title'],
        'image': (p['images'] as List).first,
        'price': p['price'],
        'originalPrice': p['originalPrice'],
        'salesCount': p['salesCount'],
        'stock': p['stock'],
        'categoryId': p['categoryId'],
      }).toList();

  return Response.json(
    body: successBody({
      ...result,
      'list': summaryList,
    }),
  );
}