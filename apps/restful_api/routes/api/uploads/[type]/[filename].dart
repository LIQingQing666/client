import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/data/database.dart';
import '../../../../lib/data/uploads.dart';

const _allowedTypes = {'images', 'videos'};

Future<Response> onRequest(
  RequestContext context,
  String type,
  String filename,
) async {
  if (context.request.method != HttpMethod.get && context.request.method != HttpMethod.head) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  if (!_allowedTypes.contains(type)) {
    return Response.json(statusCode: 404, body: errorBody(404, '资源不存在'));
  }

  if (!isSafeFilename(filename)) {
    return Response.json(statusCode: 400, body: errorBody(400, '文件名非法'));
  }

  final file = File('${uploadDirFor(type).path}/$filename');
  if (!file.existsSync()) {
    return Response.json(statusCode: 404, body: errorBody(404, '资源不存在'));
  }

  final length = await file.length();
  final mime = mimeFor(filename);

  // Honor Range requests so video <video> elements can seek and stream.
  final rangeHeader = context.request.headers['range'];
  if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
    final range = _parseRange(rangeHeader, length);
    if (range == null) {
      return Response(
        statusCode: 416,
        headers: {'content-range': 'bytes */$length'},
      );
    }
    final (start, end) = range;
    final chunkLength = end - start + 1;
    return Response.stream(
      statusCode: 206,
      body: file.openRead(start, end + 1),
      headers: {
        'content-type': mime,
        'content-length': '$chunkLength',
        'content-range': 'bytes $start-$end/$length',
        'accept-ranges': 'bytes',
        'cache-control': 'public, max-age=31536000',
      },
    );
  }

  if (context.request.method == HttpMethod.head) {
    return Response(
      headers: {
        'content-type': mime,
        'content-length': '$length',
        'accept-ranges': 'bytes',
        'cache-control': 'public, max-age=31536000',
      },
    );
  }

  return Response.stream(
    body: file.openRead(),
    headers: {
      'content-type': mime,
      'content-length': '$length',
      'accept-ranges': 'bytes',
      'cache-control': 'public, max-age=31536000',
    },
  );
}

(int, int)? _parseRange(String header, int total) {
  final spec = header.substring('bytes='.length);
  final parts = spec.split('-');
  if (parts.length != 2) return null;
  final startStr = parts[0].trim();
  final endStr = parts[1].trim();

  int start;
  int end;
  if (startStr.isEmpty) {
    // Suffix range: last N bytes.
    final suffix = int.tryParse(endStr);
    if (suffix == null || suffix <= 0) return null;
    start = total - suffix;
    if (start < 0) start = 0;
    end = total - 1;
  } else {
    final parsedStart = int.tryParse(startStr);
    if (parsedStart == null) return null;
    start = parsedStart;
    end = endStr.isEmpty ? total - 1 : (int.tryParse(endStr) ?? -1);
    if (end < 0) return null;
    if (end >= total) end = total - 1;
  }

  if (start > end || start >= total) return null;
  return (start, end);
}
