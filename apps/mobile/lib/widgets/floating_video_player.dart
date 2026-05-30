import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/app_constants.dart';
import '../models/live_model.dart';
import '../utils/responsive_helper.dart';

/// A draggable, boundary-aware floating video player for PIP mode.
///
/// Displays a live video stream in a small window that can be dragged
/// around the screen.  Tapping the window returns to the full live room;
/// the close button fully disposes the PIP.
final class FloatingVideoPlayer extends StatefulWidget {
  const FloatingVideoPlayer({
    super.key,
    required this.controller,
    required this.roomInfo,
    required this.onTap,
    required this.onClose,
  });

  final VideoPlayerController controller;
  final LiveRoomInfo roomInfo;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<FloatingVideoPlayer> createState() => _FloatingVideoPlayerState();
}

final class _FloatingVideoPlayerState extends State<FloatingVideoPlayer> {
  // Default position: bottom-right corner
  late Offset _position;
  Offset? _dragStart;
  Size? _screenSize;

  double get _pipWidth => ResponsiveHelper.isSmallScreen(context) ? 120 : 150;
  double get _pipHeight => _pipWidth * 9 / 16;

  @override
  void initState() {
    super.initState();
    // Position will be set in didChangeDependencies when we have a context.
    _position = Offset.zero;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    if (_screenSize != size) {
      _screenSize = size;
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      _position = Offset(
        size.width - _pipWidth - AppDimens.paddingLg,
        size.height - _pipHeight - bottomPadding - 70,
      );
    }
  }

  Offset _clampPosition(Offset pos) {
    final screen = _screenSize ?? MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Offset(
      pos.dx.clamp(0.0, screen.width - _pipWidth),
      pos.dy.clamp(topPadding, screen.height - _pipHeight - bottomPadding - 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      width: _pipWidth,
      height: _pipHeight,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (details) {
          _dragStart = _position;
        },
        onPanUpdate: (details) {
          if (_dragStart == null) return;
          setState(() {
            _position = _clampPosition(_dragStart! + details.delta);
          });
          _dragStart = _position;
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(color: Colors.white.withAlpha(60), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(120),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video surface
              if (controller.value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),

              // Top control bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(140),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      // Room title (truncated)
                      Expanded(
                        child: Text(
                          widget.roomInfo.title,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Close button
                      GestureDetector(
                        onTap: widget.onClose,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // "返回直播间" hint at the bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha(120),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '返回直播间',
                    style: TextStyle(fontSize: 9, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
