import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_constants.dart';
import '../models/live_model.dart';
import '../provider/live_provider.dart';

final class DanmakuOverlay extends ConsumerStatefulWidget {
  const DanmakuOverlay({super.key});

  @override
  ConsumerState<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

final class _DanmakuOverlayState extends ConsumerState<DanmakuOverlay>
    with TickerProviderStateMixin {
  final List<_AnimatedDanmaku> _activeItems = [];
  final math.Random _random = math.Random();
  int _lastMessageCount = 0;
  static const int _maxActive = 12;

  // ── Lane system ──
  // Each lane is ~28 px tall.  We track progress (0..1) for the danmaku
  // currently occupying each lane so we know when a new danmaku can enter.
  static const double _laneHeight = 28.0;
  static const double _topPadding = 20.0;
  final List<double> _laneProgress = []; // filled lazily

  @override
  void initState() {
    super.initState();
    _lastMessageCount = ref.read(liveProvider).messages.length;
  }

  /// Pick the best lane for a new danmaku.
  /// Returns (laneIndex, startY).
  (int, double) _pickLane() {
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = (screenHeight * 0.40).clamp(80.0, 400.0);
    final laneCount = (availableHeight / _laneHeight).floor().clamp(1, 10);

    // Ensure _laneProgress has enough entries.
    while (_laneProgress.length < laneCount) {
      _laneProgress.add(0.0);
    }

    // Find the lane with the lowest progress (earliest to clear),
    // but only if the existing danmaku has moved past 55% — otherwise
    // we risk immediate overlap.
    int bestLane = 0;
    double bestProgress = double.infinity;
    for (int i = 0; i < laneCount; i++) {
      final p = _laneProgress[i];
      // A lane is "free" if its current danmaku is past the half-way point
      // or if the lane was never used (p == 0).
      if (p < bestProgress) {
        bestProgress = p;
        bestLane = i;
      }
    }

    // If the best lane's progress is above 0 (occupied), only allow a new
    // danmaku if the old one is far enough ahead to avoid overlap.
    if (bestProgress > 0.0 && bestProgress < 0.55) {
      // All lanes still blocked — pick the one closest to clearing.
      // We'll still offset slightly to reduce overlap.
    }

    final startY = _topPadding + bestLane * _laneHeight;
    return (bestLane, startY);
  }

  void _spawnDanmaku(LiveMessage message) {
    if (!mounted) return;

    // Drop oldest if too many active.
    while (_activeItems.length >= _maxActive) {
      final oldest = _activeItems.removeAt(0);
      oldest.controller.dispose();
    }

    final duration = Duration(milliseconds: 4000 + _random.nextInt(3000));
    final controller = AnimationController(vsync: this, duration: duration);
    final fontSize = 12.0 + _random.nextDouble() * 3;

    final (lane, startY) = _pickLane();
    _laneProgress[lane] = 1.0; // mark lane as fully occupied

    final item = _AnimatedDanmaku(
      message: message,
      controller: controller,
      startY: startY,
      fontSize: fontSize,
      lane: lane,
    );

    _activeItems.add(item);

    // Drive the animation and update lane occupancy as it progresses.
    controller.addListener(() {
      if (_laneProgress.length > lane) {
        _laneProgress[lane] = 1.0 - controller.value; // 1→0 as it scrolls
      }
    });

    controller.forward().then((_) {
      if (mounted) {
        _activeItems.remove(item);
        controller.dispose();
        if (_laneProgress.length > lane) {
          _laneProgress[lane] = 0.0; // lane fully free
        }
        setState(() {});
      }
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LiveState>(liveProvider, (prev, next) {
      if (next.messages.length > _lastMessageCount) {
        for (int i = _lastMessageCount; i < next.messages.length; i++) {
          _spawnDanmaku(next.messages[i]);
        }
        _lastMessageCount = next.messages.length;
      }
    });

    // Remove disposed items from tracking.
    _activeItems.removeWhere((item) => item.controller.isCompleted);

    return IgnorePointer(
      child: Stack(
        children: _activeItems.map((item) {
          return Positioned(
            top: item.startY,
            left: 0,
            right: 0,
            child: _DanmakuSlide(
              controller: item.controller,
              message: item.message,
              fontSize: item.fontSize,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    for (final item in _activeItems) {
      item.controller.dispose();
    }
    _activeItems.clear();
    super.dispose();
  }
}

final class _AnimatedDanmaku {
  _AnimatedDanmaku({
    required this.message,
    required this.controller,
    required this.startY,
    required this.fontSize,
    required this.lane,
  });

  final LiveMessage message;
  final AnimationController controller;
  final double startY;
  final double fontSize;
  final int lane;
}

final class _DanmakuSlide extends AnimatedWidget {
  const _DanmakuSlide({
    required AnimationController controller,
    required this.message,
    required this.fontSize,
  }) : super(listenable: controller);

  final LiveMessage message;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final screenWidth = MediaQuery.of(context).size.width;

    // Slide from right edge to left until fully off screen.
    final xOffset = screenWidth * (1.0 - animation.value) -
        (animation.value * 200); // extra offset for bubble width

    return Transform.translate(
      offset: Offset(xOffset, 0),
      child: _DanmakuBubble(
        message: message,
        fontSize: fontSize,
      ),
    );
  }
}

final class _DanmakuBubble extends StatelessWidget {
  const _DanmakuBubble({required this.message, required this.fontSize});

  final LiveMessage message;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final isSystem = message.isSystem;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingSm,
        vertical: AppDimens.paddingXs,
      ),
      decoration: BoxDecoration(
        color: isSystem
            ? AppColors.accent.withAlpha(180)
            : Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Text(
        isSystem
            ? message.content
            : '${message.userName}：${message.content}',
        style: TextStyle(
          fontSize: fontSize,
          color: isSystem ? AppColors.background : Colors.white,
          fontWeight: isSystem ? FontWeight.w600 : FontWeight.w400,
          shadows: const [
            Shadow(
                color: Colors.black54, blurRadius: 2, offset: Offset(1, 1)),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
