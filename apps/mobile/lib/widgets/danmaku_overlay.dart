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

  @override
  void initState() {
    super.initState();
    _lastMessageCount = ref.read(liveProvider).messages.length;
  }

  void _spawnDanmaku(LiveMessage message) {
    if (!mounted) return;

    // Drop oldest if too many active
    while (_activeItems.length >= _maxActive) {
      final oldest = _activeItems.removeAt(0);
      oldest.controller.dispose();
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final startY = _random.nextDouble() * (screenHeight * 0.40) + 20;
    final duration = Duration(milliseconds: 4000 + _random.nextInt(3000));
    final controller = AnimationController(vsync: this, duration: duration);

    final fontSize = 12.0 + _random.nextDouble() * 3;

    final item = _AnimatedDanmaku(
      message: message,
      controller: controller,
      startY: startY,
      fontSize: fontSize,
    );

    _activeItems.add(item);

    controller.forward().then((_) {
      if (mounted) {
        _activeItems.remove(item);
        controller.dispose();
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

    // Remove disposed items from tracking
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
  });

  final LiveMessage message;
  final AnimationController controller;
  final double startY;
  final double fontSize;
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

    // Slide from right edge to left until fully off screen
    final xOffset = screenWidth * (1.0 - animation.value)
        - (animation.value * 200); // extra offset for bubble width

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
            Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 1)),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}