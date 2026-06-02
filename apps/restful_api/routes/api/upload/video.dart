import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../../../lib/data/database.dart';
import '../../../lib/data/uploads.dart';
import '../../../lib/middleware/auth.dart' show requireUser;

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: errorBody(405, 'Method Not Allowed'));
  }

  try {
    requireUser(context);
  } on Response catch (r) {
    return r;
  }

  final contentType = context.request.headers['content-type'] ?? '';
  if (!contentType.toLowerCase().contains('multipart/form-data')) {
    return Response.json(
      statusCode: 400,
      body: errorBody(400, '请使用 multipart/form-data 上传视频'),
    );
  }

  final FormData form;
  try {
    form = await context.request.formData();
  } catch (_) {
    return Response.json(statusCode: 400, body: errorBody(400, '表单数据解析失败'));
  }

  final file = form.files['file'];
  if (file == null) {
    return Response.json(statusCode: 400, body: errorBody(400, '缺少字段: file'));
  }

  final ext = extensionOf(file.name);
  if (ext == null || !videoExtensions.contains(ext)) {
    return Response.json(
      statusCode: 400,
      body: errorBody(400, '不支持的视频格式，仅支持: ${videoExtensions.join(', ')}'),
    );
  }

  final filename = generateUploadName(ext);
  final dir = uploadDirFor('videos');
  final savedFile = File('${dir.path}/$filename');
  final sink = savedFile.openWrite();

  var total = 0;
  var aborted = false;
  try {
    await for (final chunk in file.openRead()) {
      total += chunk.length;
      if (total > maxVideoBytes) {
        aborted = true;
        break;
      }
      sink.add(chunk);
    }
    await sink.flush();
  } finally {
    await sink.close();
  }

  if (aborted) {
    if (savedFile.existsSync()) {
      await savedFile.delete();
    }
    return Response.json(
      statusCode: 413,
      body: errorBody(413, '视频大小超过限制 (${maxVideoBytes ~/ (1024 * 1024)}MB)'),
    );
  }

  return Response.json(
    statusCode: 201,
    body: successBody({
      'url': '/api/uploads/videos/$filename',
      'filename': filename,
      'size': total,
      'contentType': mimeFor(filename),
    }, message: '上传成功'),
  );
}
