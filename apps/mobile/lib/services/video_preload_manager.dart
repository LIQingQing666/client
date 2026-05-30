import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/app_constants.dart';
import 'player_pool.dart';

/// Status of a single preload task.
enum PreloadStatus { pending, loading, done, cancelled, failed }

/// A single video preload task in the queue.
final class VideoPreloadTask {
  VideoPreloadTask({
    required this.videoId,
    required this.url,
    this.priority = 0,
  });

  final String videoId;
  final String url;
  int priority;
  PreloadStatus status = PreloadStatus.pending;
  Completer<void>? _completer;

  Future<void> get future => (_completer ??= Completer<void>()).future;
}

/// Manages a priority-based preload queue for videos.
///
/// Uses [Connectivity] to pause preloading on cellular networks when
/// [wifiOnly] is true.  Integrates with [PlayerPool] for actual
/// player acquisition and eviction.
final class VideoPreloadManager {
  VideoPreloadManager({
    required this.pool,
    required this.connectivity,
    this.maxConcurrent = 1,
    this.wifiOnly = AppConstants.preloadWifiOnly,
    this.timeout = AppConstants.preloadTimeout,
    this.startupDelay = const Duration(milliseconds: 800),
  }) {
    _subscription = connectivity.onConnectivityChanged.listen(_onNetworkChanged);
  }

  final PlayerPool pool;
  final Connectivity connectivity;
  final int maxConcurrent;
  final bool wifiOnly;
  final Duration timeout;
  final Duration startupDelay;

  final List<VideoPreloadTask> _queue = [];
  int _loadingCount = 0;
  bool _isOnWifi = true;
  bool _startupComplete = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Whether the manager is currently allowed to process tasks.
  bool get canPreload => !wifiOnly || _isOnWifi;

  /// Number of pending + loading tasks.
  int get queueLength => _queue.length;

  /// Enqueue a video for preloading.
  ///
  /// If the video is already in the queue or already acquired, this is a no-op.
  /// Returns a [Future] that completes when preloading finishes (or fails).
  Future<void> enqueue(String videoId, String url, {int priority = 0}) {
    // Already in pool — nothing to do.
    if (pool.getController(videoId) != null) {
      return Future.value();
    }

    // Already queued — bump priority if higher.
    for (final task in _queue) {
      if (task.videoId == videoId) {
        if (priority > task.priority) {
          task.priority = priority;
        }
        return task.future;
      }
    }

    final task = VideoPreloadTask(videoId: videoId, url: url, priority: priority);
    _queue.add(task);
    // Keep the queue sorted: higher priority first.
    _queue.sort((a, b) => b.priority.compareTo(a.priority));

    // Delay first preload to let the current video finish its initial buffer.
    if (!_startupComplete) {
      _startupComplete = true;
      Future.delayed(startupDelay, () {
        _processQueue();
      });
    } else {
      _processQueue();
    }
    return task.future;
  }

  /// Cancel a specific preload task.
  void cancel(String videoId) {
    _queue.removeWhere((t) {
      if (t.videoId == videoId) {
        t.status = PreloadStatus.cancelled;
        t._completer?.complete();
        return true;
      }
      return false;
    });
    pool.cancelPreload(videoId);
  }

  /// Cancel all pending preloads.
  void cancelAll() {
    for (final task in _queue) {
      task.status = PreloadStatus.cancelled;
      task._completer?.complete();
    }
    _queue.clear();
  }

  void _processQueue() {
    if (!canPreload) {
      // Pause all pending tasks when we shouldn't be preloading.
      return;
    }

    while (_loadingCount < maxConcurrent && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);

      // Skip already-handled tasks.
      if (task.status == PreloadStatus.cancelled) continue;

      _loadingCount++;
      task.status = PreloadStatus.loading;

      _preloadOne(task).then((_) {
        _loadingCount--;
        _processQueue();
      });
    }
  }

  Future<void> _preloadOne(VideoPreloadTask task) async {
    try {
      await pool.preload(task.videoId, task.url).timeout(timeout);
      task.status = PreloadStatus.done;
      task._completer?.complete();
    } on TimeoutException {
      debugPrint('[Preload] timeout: ${task.videoId}');
      task.status = PreloadStatus.failed;
      task._completer?.completeError(TimeoutException('Preload timed out'));
      pool.cancelPreload(task.videoId);
    } on Exception catch (e) {
      debugPrint('[Preload] failed: ${task.videoId} - $e');
      task.status = PreloadStatus.failed;
      task._completer?.completeError(e);
    }
  }

  void _onNetworkChanged(List<ConnectivityResult> results) {
    final wasWifi = _isOnWifi;
    _isOnWifi = results.contains(ConnectivityResult.wifi);

    if (!wasWifi && _isOnWifi) {
      // Switched back to WiFi — resume.
      _processQueue();
    } else if (wasWifi && !_isOnWifi && wifiOnly) {
      // Switched to cellular — cancel pending.
      cancelAll();
    }
  }

  void dispose() {
    _subscription?.cancel();
    cancelAll();
  }
}
