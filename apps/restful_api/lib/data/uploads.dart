import 'dart:io';
import 'dart:math';

/// Resolves the project root directory, mirroring the logic in database.dart so
/// uploads land alongside the JSON store regardless of how the server is launched.
String _resolveProjectRoot() {
  try {
    final scriptDir = Directory(Platform.script.toFilePath()).parent;
    if (scriptDir.path.endsWith('.dart_frog') || scriptDir.path.endsWith('.dart_frog/')) {
      return scriptDir.parent.path;
    }
    return scriptDir.path;
  } catch (_) {
    return Directory.current.path;
  }
}

final String _projectRoot = _resolveProjectRoot();

/// Root directory that holds all uploaded files.
final Directory uploadsRoot = Directory('$_projectRoot/data/uploads');

Directory uploadDirFor(String type) {
  final dir = Directory('${uploadsRoot.path}/$type');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return dir;
}

const Set<String> imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
const Set<String> videoExtensions = {'mp4', 'mov', 'avi', 'webm', 'm4v', 'mkv'};

const int maxImageBytes = 10 * 1024 * 1024; // 10MB
const int maxVideoBytes = 200 * 1024 * 1024; // 200MB

const Map<String, String> _mimeByExt = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'bmp': 'image/bmp',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'avi': 'video/x-msvideo',
  'webm': 'video/webm',
  'm4v': 'video/x-m4v',
  'mkv': 'video/x-matroska',
};

String? extensionOf(String filename) {
  final idx = filename.lastIndexOf('.');
  if (idx < 0 || idx == filename.length - 1) return null;
  return filename.substring(idx + 1).toLowerCase();
}

String mimeFor(String filename) {
  final ext = extensionOf(filename);
  return _mimeByExt[ext] ?? 'application/octet-stream';
}

/// Builds a unique filename so concurrent uploads don't collide.
String generateUploadName(String ext) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final rand = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '${ts}_$rand.$ext';
}

/// Rejects any filename that could break out of the upload directory.
bool isSafeFilename(String name) {
  if (name.isEmpty) return false;
  if (name.contains('..') || name.contains('/') || name.contains('\\')) return false;
  return true;
}
