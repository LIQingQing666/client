import 'dart:async';

import 'package:video_player/video_player.dart';

final class PlayerPool {
  PlayerPool({this.poolSize = 3});

  final int poolSize;
  final Map<String, _PooledPlayer> _players = {};
  // Track which videoIds are currently initializing to avoid duplicate inits.
  final Set<String> _initializing = {};

  VideoPlayerController? getController(String videoId) {
    return _players[videoId]?.controller;
  }

  Future<VideoPlayerController> acquire(String videoId, String url) async {
    final existing = _players[videoId];
    if (existing != null) {
      existing.refCount++;
      return existing.controller;
    }

    // Deduplicate by URL: if the same URL is already loaded, reuse the
    // controller and alias the entry instead of duplicating it.
    // Seek to the beginning so consecutive videos with the same file don't
    // appear to continue from the previous video's playback position.
    for (final entry in _players.entries) {
      if (entry.value.url == url) {
        entry.value.refCount++;
        _players[videoId] = entry.value; // alias — same refCount, same controller
        entry.value.controller.seekTo(Duration.zero);
        return entry.value.controller;
      }
    }

    // Guard against concurrent initializations of the same videoId.
    if (_initializing.contains(videoId)) {
      // Wait briefly for the in-flight init to complete, then retry.
      await Future.delayed(const Duration(milliseconds: 200));
      if (_players.containsKey(videoId)) {
        _players[videoId]!.refCount++;
        return _players[videoId]!.controller;
      }
    }
    _initializing.add(videoId);

    try {
      _evictIfNeeded();

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Video init timeout'),
      );
      await controller.setLooping(true);
      await controller.setVolume(1.0);

      _players[videoId] = _PooledPlayer(
        controller: controller,
        refCount: 1,
        url: url,
      );

      return controller;
    } finally {
      _initializing.remove(videoId);
    }
  }

  Future<void> preload(String videoId, String url) async {
    if (_players.containsKey(videoId)) {
      return;
    }

    try {
      await acquire(videoId, url);
    } on Exception {
      // Preload failure is non-fatal — the player will retry on acquire.
    }
  }

  void cancelPreload(String videoId) {
    final entry = _players[videoId];
    if (entry == null || entry.refCount > 0) {
      return;
    }
    _disposePlayer(videoId);
  }

  int get activeCount => _players.length;

  void release(String videoId, {bool dispose = false}) {
    final entry = _players[videoId];
    if (entry == null) {
      return;
    }

    entry.refCount--;
    if (entry.refCount <= 0) {
      entry.controller.pause();
      if (dispose) {
        _disposePlayer(videoId);
      }
    }
  }

  void _evictIfNeeded() {
    if (_players.length < poolSize) {
      return;
    }

    String? oldestId;
    int minRef = 999;
    for (final entry in _players.entries) {
      if (entry.value.refCount < minRef) {
        minRef = entry.value.refCount;
        oldestId = entry.key;
      }
    }

    if (oldestId != null) {
      _disposePlayer(oldestId);
    }
  }

  void _disposePlayer(String videoId) {
    final entry = _players.remove(videoId);
    entry?.controller.dispose();
  }

  void dispose() {
    for (final entry in _players.values) {
      entry.controller.dispose();
    }
    _players.clear();
  }
}

final class _PooledPlayer {
  _PooledPlayer({required this.controller, required this.refCount, required this.url});

  final VideoPlayerController controller;
  final String url;
  int refCount;
}
