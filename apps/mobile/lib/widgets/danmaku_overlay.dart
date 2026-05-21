import 'dart:async';
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

final class _DanmakuOverlayState extends ConsumerState<DanmakuOverlay> {
  final List<_DanmakuItem> _activeItems = [];
  final math.Random _random = math.Random();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _lastMessageCount = ref.read(liveProvider).messages.length;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentCount = ref.read(liveProvider).messages.length;
    if (currentCount > _lastMessageCount) {
      final newMessages = ref.read(liveProvider).messages;
      for (int i = _lastMessageCount; i < newMessages.length; i++) {
        _spawnDanmaku(newMessages[i]);
      }
      _lastMessageCount = currentCount;
    }
  }

  void _spawnDanmaku(LiveMessage message) {
    final screenHeight = MediaQuery.of(context).size.height;
    final startY = _random.nextDouble() * (screenHeight * 0.45) + 30;
    final speed = _random.nextDouble() * 3 + 4;
    final item = _DanmakuItem(
      message: message,
      startY: startY,
      speed: speed,
    );
    _activeItems.add(item);

    Timer(const Duration(seconds: 8), () {
      if (mounted) {
        _activeItems.remove(item);
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

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: _activeItems.map((item) {
            return Positioned(
              top: item.startY,
              child: _DanmakuBubble(message: item.message),
            );
          }).toList(),
        ),
      ),
    );
  }
}

final class _DanmakuItem {
  _DanmakuItem({
    required this.message,
    required this.startY,
    required this.speed,
  });

  final LiveMessage message;
  final double startY;
  final double speed;
}

final class _DanmakuBubble extends StatelessWidget {
  const _DanmakuBubble({required this.message});

  final LiveMessage message;

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
        isSystem ? message.content : '${message.userName}：${message.content}',
        style: TextStyle(
          fontSize: 12,
          color: isSystem ? AppColors.background : Colors.white,
          fontWeight: isSystem ? FontWeight.w600 : FontWeight.w400,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
