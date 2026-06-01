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
      body: errorBody(400, '请使用 multipart/form-data 上传图片'),
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

  final originalName = file.name;
  final ext = extensionOf(originalName);
  if (ext == null || !imageExtensions.contains(ext)) {
    return Response.json(
      statusCode: 400,
      body: errorBody(400, '不支持的图片格式，仅支持: ${imageExtensions.join(', ')}'),
    );
  }

  final bytes = await file.readAsBytes();
  if (bytes.length > maxImageBytes) {
    return Response.json(
      statusCode: 413,
      body: errorBody(413, '图片大小超过限制 (${maxImageBytes ~/ (1024 * 1024)}MB)'),
    );
  }

  final filename = generateUploadName(ext);
  final dir = uploadDirFor('images');
  final savedFile = File('${dir.path}/$filename');
  await savedFile.writeAsBytes(bytes, flush: true);

  return Response.json(
    statusCode: 201,
    body: successBody({
      'url': '/api/uploads/images/$filename',
      'filename': filename,
      'size': bytes.length,
      'contentType': mimeFor(filename),
    }, message: '上传成功'),
  );
}
