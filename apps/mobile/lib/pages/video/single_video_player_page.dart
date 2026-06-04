import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_constants.dart';
import '../../models/product_model.dart';
import '../../models/video_model.dart';
import '../../provider/cart_provider.dart';
import '../../provider/favorite_provider.dart';
import '../../provider/feed_provider.dart';
import '../../provider/follow_provider.dart';
import '../../widgets/floating_product_card.dart';
import '../../widgets/product_detail_sheet.dart';

final class SingleVideoPlayerPage extends ConsumerStatefulWidget {
  const SingleVideoPlayerPage({
    super.key,
    required this.videoId,
    this.seekTo,
  });

  final String videoId;
  final int? seekTo;

  @override
  ConsumerState<SingleVideoPlayerPage> createState() =>
      _SingleVideoPlayerPageState();
}

final class _SingleVideoPlayerPageState
    extends ConsumerState<SingleVideoPlayerPage> {
  VideoPlayerController? _controller;
  VideoModel? _video;
  ProductModel? _product;
  bool _loading = true;
  bool _videoReady = false;
  bool _videoError = false;
  bool _highlightActive = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _onChanged() {
    if (!mounted || _controller == null) return;
    final v = _controller!.value;
    if (v.isInitialized && !_videoReady) {
      _controller!.setLooping(true);
      _controller!.play();
      if (widget.seekTo != null && widget.seekTo! > 0) {
        _applySeek(_controller!, widget.seekTo!);
      }
      setState(() { _videoReady = true; _loading = false; });
    }
    if (v.hasError) {
      debugPrint('[SingleVideo] controller error: ${v.errorDescription}');
      if (mounted) setState(() { _loading = false; _videoError = true; });
    }
  }

  Future<void> _load() async {
    try {
      if (kDebugMode) debugPrint('[SingleVideo] → fetch video ${widget.videoId}');
      final api = ref.read(videoApiProvider);
      final detail = await api.getVideoDetail(widget.videoId).timeout(
        const Duration(seconds: 10),
      );
      if (!mounted) return;

      _video = detail.video;
      if (detail.products.isNotEmpty) {
        _product = ProductModel.fromJson(detail.products.first);
      }

      final url = _video!.videoUrl;
      if (kDebugMode) debugPrint('[SingleVideo] videoUrl=$url');
      if (url.isEmpty) {
        if (mounted) setState(() { _loading = false; _videoError = true; });
        return;
      }

      // Create a fresh controller.
      if (kDebugMode) debugPrint('[SingleVideo] → creating controller...');
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      controller.addListener(_onChanged);

      if (kDebugMode) debugPrint('[SingleVideo] → initializing...');
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) {
        controller.dispose();
        return;
      }

      // Already handled by listener if it fired first, but call explicitly
      // in case the listener hasn't fired yet (race-safe).
      if (!_videoReady) {
        if (kDebugMode) debugPrint('[SingleVideo] → playing');
        controller.setLooping(true);
        controller.play();
        if (widget.seekTo != null && widget.seekTo! > 0) {
          _applySeek(controller, widget.seekTo!);
        }
        setState(() { _videoReady = true; _loading = false; });
      }
    } catch (e) {
      debugPrint('[SingleVideo] ERROR: $e');
      if (mounted) setState(() { _loading = false; _videoError = true; });
    }
  }

  void _applySeek(VideoPlayerController c, int seekTo) {
    final durMs = c.value.duration.inMilliseconds;
    if (durMs <= 0) return;
    final clampedMs = (seekTo * 1000).clamp(0, (durMs - 500).clamp(0, durMs));
    c.seekTo(Duration(milliseconds: clampedMs));
    if (kDebugMode) {
      debugPrint('[SingleVideo] seek to ${clampedMs}ms / ${durMs}ms');
    }
    setState(() => _highlightActive = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlightActive = false);
    });
  }

  // ──────────────────────── UI ────────────────────────

  void _showProductDetail() {
    if (_product == null) return;
    final product = _product!;
    final favState = ref.read(favoriteProvider);
    showProductDetailSheet(
      context: context,
      product: product,
      onAddToCart: (spec, quantity, couponId) {
        Navigator.of(context).pop();
        ref.read(cartProvider.notifier).addToCart(
          productId: product.id, spec: spec, quantity: quantity,
        );
      },
      onBuyNow: (spec, quantity, couponId) {
        context.pushNamed('orderConfirm', queryParameters: <String, String>{
          'from': 'buy_now',
          'total': (product.price * quantity).toString(),
          'count': quantity.toString(),
          'product_id': product.id,
          'product_name': product.name,
          'product_price': product.price.toString(),
          'product_cover': product.coverUrl,
          'product_spec': spec,
          'quantity': quantity.toString(),
        });
      },
      onSeekToTime: (product.highlightTime > 0 || product.segments.isNotEmpty)
          ? (t) {
              Navigator.of(context).pop();
              if (_controller != null && _videoReady) _applySeek(_controller!, t);
            }
          : null,
      onFavorite: () {
        ref.read(favoriteProvider.notifier).toggleProductFavorite(
          id: product.id, name: product.name,
          coverUrl: product.coverUrl, price: product.price,
          videoId: product.videoId, highlightTime: product.highlightTime,
        );
      },
      isFavorited: favState.isFavorited(product.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_videoError || _video == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_outline, size: 56, color: Colors.white54),
              const SizedBox(height: AppDimens.paddingSm),
              const Text('视频加载失败', style: TextStyle(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: AppDimens.paddingLg),
              ElevatedButton.icon(
                onPressed: () {
                  _controller?.dispose();
                  _controller = null;
                  setState(() { _loading = true; _videoError = false; _videoReady = false; });
                  _load();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新加载'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final video = _video!;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          if (_controller != null && _videoReady)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _controller!,
              builder: (_, value, __) {
                if (!value.isInitialized || value.size.isEmpty) {
                  return _buildCover(video);
                }
                return FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: value.size.width,
                    height: value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                );
              },
            )
          else
            _buildCover(video),

          // Seek highlight
          if (_highlightActive)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent.withAlpha(180), width: 3),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(color: AppColors.accent.withAlpha(80), blurRadius: 20, spreadRadius: 4),
                    ],
                  ),
                ),
              ),
            ),

          // Tap to pause/play
          GestureDetector(
            onTap: () {
              if (_controller == null || !_videoReady) return;
              if (_controller!.value.isPlaying) {
                _controller!.pause();
              } else {
                _controller!.play();
              }
              setState(() {});
            },
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),

          if (_videoReady && _controller != null && !_controller!.value.isPlaying)
            const Center(child: Icon(Icons.play_circle_filled, size: 64, color: Colors.white70)),

          // Top gradient
          Positioned(
            top: 0, left: 0, right: 0, height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withAlpha(140), Colors.black.withAlpha(20)],
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + AppDimens.paddingSm,
            left: AppDimens.paddingLg,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            ),
          ),

          // Info + actions
          Positioned(
            left: AppDimens.paddingLg, right: 80, bottom: bottomInset + 60,
            child: _Info(video: video),
          ),
          Positioned(
            right: AppDimens.paddingMd, bottom: 180,
            child: _Actions(video: video),
          ),

          // Product card
          if (_product != null)
            Positioned(
              left: AppDimens.paddingLg, bottom: bottomInset + 180,
              child: FloatingProductCard(
                product: _product!, onTap: _showProductDetail, disableAutoFade: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCover(VideoModel v) {
    return CachedNetworkImage(
      imageUrl: v.coverUrl, fit: BoxFit.cover,
      width: double.infinity, height: double.infinity,
      placeholder: (_, __) => Container(color: AppColors.surface),
      errorWidget: (_, __, ___) => Container(color: AppColors.surface),
    );
  }
}

final class _Info extends ConsumerWidget {
  const _Info({required this.video});
  final VideoModel video;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isF = ref.watch(followProvider).followingIds.contains(video.authorId);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        CircleAvatar(radius: 18, backgroundColor: AppColors.card,
          child: Text(video.authorName.isNotEmpty ? video.authorName[0] : '?', style: AppTextStyles.bodySmall)),
        const SizedBox(width: AppDimens.paddingSm),
        Text(video.authorName, style: AppTextStyles.bodyLarge),
        const SizedBox(width: AppDimens.paddingSm),
        GestureDetector(
          onTap: () async {
            try { await ref.read(followProvider.notifier).toggleFollow(video.authorId); } on Exception {}
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingSm, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: isF ? AppColors.textHint : AppColors.primary),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Text(isF ? '已关注' : '关注',
              style: TextStyle(fontSize: 12, color: isF ? AppColors.textHint : AppColors.primary, fontWeight: FontWeight.w500)),
          ),
        ),
      ]),
      const SizedBox(height: AppDimens.paddingSm),
      Text(video.title, style: AppTextStyles.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: AppDimens.paddingXs),
      Text(video.description, style: AppTextStyles.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
    ]);
  }
}

final class _Actions extends ConsumerWidget {
  const _Actions({required this.video});
  final VideoModel video;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(favoriteProvider).isFavorited(video.id);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _Btn(icon: video.isLiked ? Icons.favorite : Icons.favorite_border,
        iconColor: video.isLiked ? AppColors.primary : null,
        label: video.likeCountText, onTap: () => ref.read(videoApiProvider).toggleLike(video.id, 'u1')),
      const SizedBox(height: AppDimens.paddingLg),
      _Btn(icon: fav ? Icons.star : Icons.star_border, iconColor: fav ? AppColors.accent : null,
        label: fav ? '已收藏' : '收藏', onTap: () {
        ref.read(favoriteProvider.notifier).toggleVideoFavorite(
          id: video.id, title: video.title, coverUrl: video.coverUrl, authorName: video.authorName,
        );
      }),
    ]);
  }
}

final class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.label, this.iconColor, this.onTap});
  final IconData icon;
  final String label;
  final Color? iconColor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 32, color: iconColor ?? Colors.white),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.bodySmall),
      ]),
    );
  }
}
