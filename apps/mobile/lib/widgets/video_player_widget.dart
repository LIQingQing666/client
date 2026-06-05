import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/app_constants.dart';
import '../models/product_model.dart';
import '../models/video_model.dart';
import '../services/player_pool.dart';
import '../utils/toast.dart';
import 'floating_product_card.dart';

final class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({
    super.key,
    required this.video,
    required this.pool,
    this.isActive = false,
    this.isMuted = false,
    this.product,
    this.onLike,
    this.onMessage,
    this.onShare,
    this.onProductTap,
    this.onFollow,
    this.onMuteToggle,
    this.onAuthorTap,
    this.onFavorite,
    this.isFavorited = false,
    this.isFollowing = false,
    this.seekTrigger,
  });

  final VideoModel video;
  final PlayerPool pool;
  final bool isActive;
  final bool isMuted;
  final ProductModel? product;
  final VoidCallback? onLike;
  final VoidCallback? onMessage;
  final VoidCallback? onShare;
  final VoidCallback? onProductTap;
  final VoidCallback? onFollow;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onFavorite;
  final bool isFavorited;
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
  bool _highlightActive = false;
  bool _initializing = false; // prevents duplicate _initPlayer calls

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
      try {
        final durationSec = _controller!.value.duration.inSeconds;
        // Clamp: don't seek past (duration - 0.5s) so we stay within the video.
        final clamped = durationSec > 0
            ? seekTo.clamp(0, (durationSec - 0.5).ceil().clamp(0, durationSec))
            : seekTo;
        _controller!.seekTo(Duration(seconds: clamped));
        _controller!.play();
        // Brief highlight flash when a seek is triggered.
        setState(() => _highlightActive = true);
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _highlightActive = false);
        });
      } on Exception {
        showToast('跳转失败，请重试');
      }
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.video.id != oldWidget.video.id) {
      _releasePlayer();
      _initPlayer();
    }
    if (widget.isMuted != oldWidget.isMuted) {
      _applyMuteState();
    }
    _syncPlayState();
  }

  Future<void> _initPlayer() async {
    if (_initializing) return;
    _initializing = true;
    try {
      final controller = await widget.pool.acquire(
        widget.video.id,
        widget.video.videoUrl,
      );

      if (!mounted) {
        widget.pool.release(widget.video.id);
        _initializing = false;
        return;
      }

      _controller = controller;
      _applyMuteState();
      controller.addListener(_onControllerUpdate);

      if (controller.value.isInitialized) {
        _onReady();
      }
      else {
        controller.addListener(_waitForInit);
      }
      _initializing = false;
    } catch (e) {
      // catch (not on Exception) — catches TypeError etc. too
      debugPrint('[VideoWidget] init error: $e');
      if (mounted) {
        setState(() {
          _isCoverVisible = true;
        });
      }
      showToast('视频加载失败');
      _initializing = false;
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
      try {
        if (!_controller!.value.isPlaying) {
          _controller!.play();
        }
        _applyMuteState();
      } catch (_) {
        // Controller may be in a bad state after fast scrolling —
        // re-initialize it.
        _releasePlayer(dispose: true);
        _initPlayer();
      }
    } else {
      try {
        _controller?.pause();
      } catch (_) { /* ignore — controller may already be disposed */ }
      _releasePlayer(dispose: false);
      if (!_isCoverVisible && mounted) {
        setState(() {
          _isCoverVisible = true;
        });
        _fadeController.value = 0;
      }
    }
  }

  void _applyMuteState() {
    if (_controller != null && _isInitialized) {
      _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
  }

  void _releasePlayer({bool dispose = false}) {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.removeListener(_waitForInit);
    widget.pool.release(widget.video.id, dispose: dispose);
    _controller = null;
    _isInitialized = false;
    _initializing = false;
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
            Builder(builder: (_) {
              final size = _controller!.value.size;
              if (size.width == 0 || size.height == 0) return _buildCover();
              return FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(_controller!),
                ),
              );
            })
          else
            _buildCover(),

          // Cover overlay with fade
          if (_isCoverVisible) _buildCover(),

          // Highlight flash when seek is triggered (product segment jump)
          if (_highlightActive)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _highlightActive ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.accent.withAlpha(180),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withAlpha(80),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

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
            onAuthorTap: widget.onAuthorTap,
            isFollowing: widget.isFollowing,
          ),

          // Right action bar (mute, like, comment, share, favorite)
          _VideoActionBar(
            video: widget.video,
            onLike: widget.onLike,
            onMessage: widget.onMessage,
            onShare: widget.onShare,
            onMuteToggle: widget.onMuteToggle,
            isMuted: widget.isMuted,
            onFavorite: widget.onFavorite,
            isFavorited: widget.isFavorited,
          ),

          // Floating product card (TikTok-style overlay)
          if (widget.product != null)
            FloatingProductCard(
              product: widget.product!,
              onTap: widget.onProductTap ?? () {},
              disableAutoFade: true,
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
  const _VideoInfoSection({required this.video, this.onFollow, this.onAuthorTap, this.isFollowing = false});

  final VideoModel video;
  final VoidCallback? onFollow;
  final VoidCallback? onAuthorTap;
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
              GestureDetector(
                onTap: onAuthorTap,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.card,
                  child: Text(
                    video.authorName.isNotEmpty
                        ? video.authorName[0]
                        : '?',
                    style: AppTextStyles.bodySmall,
                  ),
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
    this.onMuteToggle,
    this.onFavorite,
    this.isMuted = false,
    this.isFavorited = false,
  });

  final VideoModel video;
  final VoidCallback? onLike;
  final VoidCallback? onMessage;
  final VoidCallback? onShare;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onFavorite;
  final bool isMuted;
  final bool isFavorited;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: AppDimens.paddingMd,
      bottom: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: isMuted ? Icons.volume_off : Icons.volume_up,
            iconColor: isMuted ? AppColors.textHint : null,
            label: isMuted ? '已静音' : '音量',
            onTap: onMuteToggle,
          ),
          const SizedBox(height: AppDimens.paddingLg),
          _ActionButton(
            icon: video.isLiked ? Icons.favorite : Icons.favorite_border,
            iconColor: video.isLiked ? AppColors.primary : null,
            label: video.likeCountText,
            onTap: onLike,
          ),
          const SizedBox(height: AppDimens.paddingLg),
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: video.commentCountText,
            onTap: onMessage,
          ),
          const SizedBox(height: AppDimens.paddingLg),
          _ActionButton(
            icon: Icons.ios_share,
            label: video.shareCount.toString(),
            onTap: onShare,
          ),
          const SizedBox(height: AppDimens.paddingLg),
          _ActionButton(
            icon: isFavorited ? Icons.star : Icons.star_border,
            label: isFavorited ? '已收藏' : '收藏',
            iconColor: isFavorited ? AppColors.accent : null,
            onTap: onFavorite,
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
    if (!value.isInitialized) return const SizedBox.shrink();
    final durationMs = value.duration.inMilliseconds;
    if (durationMs <= 0) return const SizedBox.shrink();
    final progress = (value.position.inMilliseconds / durationMs).clamp(0.0, 1.0);

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
