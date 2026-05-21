import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/app_constants.dart';
import '../models/video_model.dart';
import '../services/player_pool.dart';
import '../utils/toast.dart';

final class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({
    super.key,
    required this.video,
    required this.pool,
    this.isActive = false,
    this.onLike,
    this.onMessage,
    this.onShare,
    this.onProductTap,
    this.onFollow,
    this.isFollowing = false,
    this.seekTrigger,
  });

  final VideoModel video;
  final PlayerPool pool;
  final bool isActive;
  final VoidCallback? onLike;
  final VoidCallback? onMessage;
  final VoidCallback? onShare;
  final VoidCallback? onProductTap;
  final VoidCallback? onFollow;
  final bool isFollowing;
  final ValueNotifier<int>? seekTrigger;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

final class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isCoverVisible = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: AppConstants.videoFadeInDuration,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    widget.seekTrigger?.addListener(_onSeekTriggered);
    _initPlayer();
  }

  void _onSeekTriggered() {
    final seekTo = widget.seekTrigger?.value;
    if (seekTo != null && seekTo > 0 && _controller != null && _isInitialized) {
      _controller!.seekTo(Duration(seconds: seekTo));
      _controller!.play();
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.video.id != oldWidget.video.id) {
      _releasePlayer();
      _initPlayer();
    }
    _syncPlayState();
  }

  Future<void> _initPlayer() async {
    try {
      final controller = await widget.pool.acquire(
        widget.video.id,
        widget.video.videoUrl,
      );

      if (!mounted) {
        return;
      }

      _controller = controller;
      controller.addListener(_onControllerUpdate);

      if (controller.value.isInitialized) {
        _onReady();
      }
      else {
        controller.addListener(_waitForInit);
      }
    }
    on Exception {
      if (mounted) {
        setState(() {
          _isCoverVisible = true;
        });
      }
      showToast('视频加载失败');
    }
  }

  void _waitForInit() {
    if (_controller?.value.isInitialized == true && mounted) {
      _controller!.removeListener(_waitForInit);
      _onReady();
    }
  }

  void _onReady() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isInitialized = true;
    });
    _syncPlayState();

    _fadeController.forward().then((_) {
      if (mounted) {
        setState(() {
          _isCoverVisible = false;
        });
      }
    });
  }

  void _onControllerUpdate() {
    if (!mounted || _controller == null) {
      return;
    }

    final isInitialized = _controller!.value.isInitialized;
    if (isInitialized && !_isInitialized) {
      _onReady();
    }
  }

  void _syncPlayState() {
    if (widget.isActive) {
      if (_controller == null) {
        _initPlayer();
        return;
      }
      _controller!.play();
    } else {
      _controller?.pause();
      _releasePlayer(dispose: true);
      if (!_isCoverVisible && mounted) {
        setState(() {
          _isCoverVisible = true;
        });
        _fadeController.value = 0;
      }
    }
  }

  void _releasePlayer({bool dispose = false}) {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.removeListener(_waitForInit);
    widget.pool.release(widget.video.id, dispose: dispose);
    _controller = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    widget.seekTrigger?.removeListener(_onSeekTriggered);
    _releasePlayer();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video layer — only render platform view when active to prevent
          // it from drawing on top of other IndexedStack children.
          if (_controller != null && _isInitialized && widget.isActive)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            _buildCover(),

          // Cover overlay with fade
          if (_isCoverVisible) _buildCover(),

          // Play/pause indicator
          if (widget.isActive && _isInitialized && !_controller!.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                size: 64,
                color: Colors.white70,
              ),
            ),

          // Bottom info section
          _VideoInfoSection(
            video: widget.video,
            onFollow: widget.onFollow,
            isFollowing: widget.isFollowing,
          ),

          // Right action bar
          _VideoActionBar(
            video: widget.video,
            onLike: widget.onLike,
            onMessage: widget.onMessage,
            onShare: widget.onShare,
            onProductTap: widget.onProductTap,
            onMusicTap: () => showToast('音乐详情'),
          ),

          // Progress bar
          if (widget.isActive && _controller != null && _isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _VideoProgressBar(controller: _controller!),
            ),

          // Loading indicator
          if (!_isInitialized && widget.isActive)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCover() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: CachedNetworkImage(
            imageUrl: widget.video.coverUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(color: AppColors.surface),
            errorWidget: (context, url, error) =>
                Container(color: AppColors.surface),
          ),
        );
      },
    );
  }

  void _handleTap() {
    if (_controller == null || !_isInitialized) {
      return;
    }

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    }
    else {
      _controller!.play();
      if (_isCoverVisible) {
        _fadeController.forward().then((_) {
          if (mounted) {
            setState(() {
              _isCoverVisible = false;
            });
          }
        });
      }
    }
    setState(() {});
  }
}

final class _VideoInfoSection extends StatelessWidget {
  const _VideoInfoSection({required this.video, this.onFollow, this.isFollowing = false});

  final VideoModel video;
  final VoidCallback? onFollow;
  final bool isFollowing;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: AppDimens.paddingLg,
      right: 80,
      bottom: AppDimens.paddingLg + 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.card,
                child: Text(
                  video.authorName.isNotEmpty
                      ? video.authorName[0]
                      : '?',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              const SizedBox(width: AppDimens.paddingSm),
              Text(
                video.authorName,
                style: AppTextStyles.bodyLarge,
              ),
              const SizedBox(width: AppDimens.paddingSm),
              GestureDetector(
                onTap: onFollow,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.paddingSm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isFollowing ? AppColors.primary.withValues(alpha: 0.15) : null,
                    border: Border.all(color: isFollowing ? AppColors.textHint : AppColors.primary),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    isFollowing ? '已关注' : '关注',
                    style: TextStyle(
                      fontSize: 12,
                      color: isFollowing ? AppColors.textHint : AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.paddingSm),
          Text(
            video.title,
            style: AppTextStyles.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimens.paddingXs),
          Text(
            video.description,
            style: AppTextStyles.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimens.paddingSm),
          if (video.tags.isNotEmpty)
            Wrap(
              spacing: AppDimens.paddingSm,
              children: video.tags.map((tag) {
                return Text(
                  '#$tag',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

final class _VideoActionBar extends StatelessWidget {
  const _VideoActionBar({
    required this.video,
    this.onLike,
    this.onMessage,
    this.onShare,
    this.onProductTap,
    this.onMusicTap,
  });

  final VideoModel video;
  final VoidCallback? onLike;
  final VoidCallback? onMessage;
  final VoidCallback? onShare;
  final VoidCallback? onProductTap;
  final VoidCallback? onMusicTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: AppDimens.paddingMd,
      bottom: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: video.isLiked ? Icons.favorite : Icons.favorite_border,
            iconColor: video.isLiked ? AppColors.primary : null,
            label: video.likeCountText,
            onTap: onLike,
          ),
          const SizedBox(height: AppDimens.paddingLg),
          _ActionButton(
            icon: Icons.message,
            label: video.commentCountText,
            onTap: onMessage,
          ),
          const SizedBox(height: AppDimens.paddingLg),
          _ActionButton(
            icon: Icons.share,
            label: video.shareCount.toString(),
            onTap: onShare,
          ),
          const SizedBox(height: AppDimens.paddingLg),
          _ActionButton(
            icon: Icons.shopping_bag_outlined,
            label: '商品',
            onTap: onProductTap,
          ),
          const SizedBox(height: AppDimens.paddingLg),
          GestureDetector(
            onTap: onMusicTap,
            child: const CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.card,
              child: Icon(Icons.music_note, color: AppColors.primary, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 32,
            color: iconColor ?? Colors.white,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

final class _VideoProgressBar extends StatefulWidget {
  const _VideoProgressBar({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}

final class _VideoProgressBarState extends State<_VideoProgressBar> {
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final durationMs = value.duration.inMilliseconds;
    final progress = durationMs > 0
        ? (value.position.inMilliseconds / durationMs).clamp(0.0, 1.0)
        : 0.0;

    // Use drag value while dragging, otherwise use actual progress
    final displayProgress = _dragValue > 0 ? _dragValue : progress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.white.withAlpha(30),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withAlpha(50),
          ),
          child: Slider(
            value: displayProgress,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) {
              final seekTo = Duration(milliseconds: (v * durationMs).toInt());
              widget.controller.seekTo(seekTo);
              setState(() => _dragValue = 0.0);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingLg,
            vertical: AppDimens.paddingXs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(
                  milliseconds: _dragValue > 0
                      ? (_dragValue * durationMs).toInt()
                      : value.position.inMilliseconds,
                )),
                style: AppTextStyles.bodySmall,
              ),
              Text(
                _formatDuration(value.duration),
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
