import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_constants.dart';
import '../../core/app_router.dart';
import '../../models/live_model.dart';
import '../../models/product_model.dart';
import '../../provider/cart_provider.dart';
import '../../provider/favorite_provider.dart';
import '../../provider/follow_provider.dart';
import '../../provider/live_provider.dart';
import '../../provider/pip_provider.dart';
import '../../utils/toast.dart';
import '../../widgets/coupon_countdown.dart';
import '../../widgets/danmaku_overlay.dart';
import '../../widgets/product_detail_sheet.dart';
import 'audience_list.dart';
import 'gift_panel.dart';

final class LiveRoomPage extends ConsumerStatefulWidget {
  const LiveRoomPage({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<LiveRoomPage> createState() => _LiveRoomPageState();
}

final class _LiveRoomPageState extends ConsumerState<LiveRoomPage> {
  final _pageController = PageController();
  int _currentIndex = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final rooms = ref.read(roomListProvider);
      final index = rooms.indexWhere((r) => r.id == widget.roomId);
      if (index >= 0 && mounted) {
        setState(() {
          _currentIndex = index;
          _initialized = true;
        });
        _pageController.jumpToPage(index);
      }
      ref.read(liveProvider.notifier).enterRoom(widget.roomId);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    ref.read(liveProvider.notifier).leaveRoom();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomListProvider);

    if (rooms.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final safeIndex = _currentIndex.clamp(0, rooms.length - 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: rooms.length,
        onPageChanged: (index) {
          if (index >= 0 && index < rooms.length) {
            setState(() => _currentIndex = index);
            ref.read(liveProvider.notifier).switchRoom(rooms[index].id);
          }
        },
        itemBuilder: (context, index) {
          final room = rooms[index];
          final isActive = index == safeIndex;
          if (isActive) {
            return _LiveRoomActiveContent(key: ValueKey('live_${room.id}'), room: room);
          }
          return _LiveRoomPlaceholder(room: room);
        },
      ),
    );
  }
}

final class _LiveRoomPlaceholder extends StatelessWidget {
  const _LiveRoomPlaceholder({required this.room});

  final LiveRoomInfo room;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: room.coverUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: AppColors.surface),
          errorWidget: (_, __, ___) => Container(color: AppColors.surface),
        ),
        Container(color: Colors.black.withAlpha(100)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_outline, size: 64, color: Colors.white54),
              const SizedBox(height: 12),
              Text(room.title, style: const TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 4),
              Text(room.authorName, style: const TextStyle(fontSize: 13, color: Colors.white54)),
            ],
          ),
        ),
      ],
    );
  }
}

final class _LiveRoomActiveContent extends ConsumerStatefulWidget {
  const _LiveRoomActiveContent({super.key, required this.room});

  final LiveRoomInfo room;

  @override
  ConsumerState<_LiveRoomActiveContent> createState() => _LiveRoomActiveContentState();
}

final class _LiveRoomActiveContentState extends ConsumerState<_LiveRoomActiveContent> {
  final _chatController = TextEditingController();
  final _chatFocusNode = FocusNode();
  bool _showChatInput = false;
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.room.videoUrl.isNotEmpty) {
      _initVideo(widget.room.videoUrl);
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatFocusNode.dispose();
    // Do NOT dispose video controller if PIP is active — it's still in use.
    final pipActive = ref.read(pipProvider).isActive;
    if (!pipActive) {
      _videoController?.pause();
      _videoController?.dispose();
    }
    super.dispose();
  }

  void _initVideo(String url) {
    if (url.isEmpty || _videoController != null) return;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoController!.setLooping(true);
        _videoController!.play();
      }).catchError((_) {});
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    ref.read(liveProvider.notifier).sendMessage(text);
    _chatController.clear();
    _chatFocusNode.unfocus();
    setState(() => _showChatInput = false);
  }

  void _toggleChatInput() {
    setState(() => _showChatInput = !_showChatInput);
    if (_showChatInput) {
      _chatFocusNode.requestFocus();
    } else {
      _chatFocusNode.unfocus();
    }
  }

  Future<void> _onFollowTap() async {
    final authorId = ref.read(liveProvider).room?.authorId;
    if (authorId == null) return;
    try {
      await ref.read(followProvider.notifier).toggleFollow(authorId);
    } on Exception {}
  }

  void _onShare() {
    final room = ref.read(liveProvider).room;
    if (room == null) return;
    Share.share('${room.authorName}的直播间，快来看看！\n${room.title}');
  }

  void _showAudienceList() {
    final state = ref.read(liveProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AudienceList(
        audiences: const [],
        onlineCount: state.onlineCount,
      ),
    );
  }

  void _showGiftPanel() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GiftPanel(
        onSelect: (gift) {
          showToast('送出了 ${gift.name}');
        },
      ),
    );
  }

  void _showProductList() {
    final products = ref.read(liveProvider).products;
    if (products.isEmpty) {
      showToast('暂无商品');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppDimens.paddingSm),
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.textHint, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),
            const Text('商品列表', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppDimens.paddingMd),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingLg),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppDimens.paddingSm),
                    padding: const EdgeInsets.all(AppDimens.paddingSm),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                          child: CachedNetworkImage(
                            imageUrl: product.coverUrl, width: 64, height: 64, fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: AppColors.card),
                            errorWidget: (_, __, ___) => Container(color: AppColors.card),
                          ),
                        ),
                        const SizedBox(width: AppDimens.paddingMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, style: AppTextStyles.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('¥${product.price.toStringAsFixed(0)}', style: AppTextStyles.priceSmall),
                                  if (product.hasDiscount) ...[
                                    const SizedBox(width: AppDimens.paddingXs),
                                    Text('¥${product.originalPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textHint, decoration: TextDecoration.lineThrough)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            ref.read(favoriteProvider.notifier).toggleProductFavorite(
                              id: product.id,
                              name: product.name,
                              coverUrl: product.coverUrl,
                              price: product.price,
                              videoId: product.videoId,
                              highlightTime: product.highlightTime,
                            );
                          },
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.card,
                            ),
                            child: Icon(
                              ref.read(favoriteProvider).isFavorited(product.id)
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: ref.read(favoriteProvider).isFavorited(product.id)
                                  ? AppColors.primary
                                  : AppColors.textHint,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.paddingSm),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _showProductDetail(context, product);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingMd, vertical: AppDimens.paddingSm),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                            ),
                            child: const Text('购买', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetail(BuildContext context, ProductModel product) {
    final favState = ref.read(favoriteProvider);
    final room = ref.read(liveProvider).room;
    showProductDetailSheet(
      context: context,
      product: product,
      onAddToCart: () {
        ref.read(cartProvider.notifier).addToCart(productId: product.id);
      },
      onBuyNow: () {
        ref.read(cartProvider.notifier).addToCart(productId: product.id);
        // Dismiss the bottom sheet first.
        Navigator.of(context).pop();
        // Enter PIP mode before navigating away so the live stream keeps playing.
        if (_videoController != null && _videoReady && room != null) {
          ref.read(pipProvider.notifier).enterPip(_videoController!, room);
          ref.read(pipProvider.notifier).onReturnToLive = () {
            // Pop all routes until we're back, then re-enter the live room.
            final router = GoRouter.of(context);
            while (router.canPop()) {
              router.pop();
            }
            context.pushReplacementNamed('liveRoom',
                pathParameters: {'roomId': widget.room.id});
          };
        }
        context.pushNamed('orderConfirm', queryParameters: <String, String>{
          'total': product.price.toString(), 'count': '1',
        });
      },
      onFavorite: () {
        ref.read(favoriteProvider.notifier).toggleProductFavorite(
          id: product.id,
          name: product.name,
          coverUrl: product.coverUrl,
          price: product.price,
          videoId: product.videoId,
          highlightTime: product.highlightTime,
        );
      },
      isFavorited: favState.isFavorited(product.id),
    );
  }

  void _onAuthorTap() {
    final room = ref.read(liveProvider).room;
    if (room == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AuthorInfoSheet(
        authorName: room.authorName,
        authorAvatar: room.authorAvatar,
        authorId: room.authorId,
        onFollow: _onFollowTap,
        isFollowing: ref.read(followProvider).followingIds.contains(room.authorId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveProvider);
    final followState = ref.watch(followProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    if (state.room == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final room = state.room!;
    final isFollowing = followState.followingIds.contains(room.authorId);

    return PopScope(
      canPop: false, // We handle back navigation ourselves.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Enter PIP mode if video is playing, then pop.
        final currentRoom = state.room;
        if (_videoController != null && _videoReady && currentRoom != null) {
          ref.read(pipProvider.notifier).enterPip(_videoController!, currentRoom);
        }
        context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: video player or cover image
          if (_videoController != null && _videoReady)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            )
          else
            CachedNetworkImage(
              imageUrl: room.coverUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppColors.surface),
              errorWidget: (_, __, ___) => Container(color: AppColors.surface),
            ),

          // Top gradient
          Positioned(
            top: 0, left: 0, right: 0, height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withAlpha(140), Colors.black.withAlpha(20)],
                ),
              ),
            ),
          ),

          // Bottom gradient
          Positioned(
            bottom: 0, left: 0, right: 0, height: 200 + bottomInset,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withAlpha(160), Colors.black.withAlpha(20)],
                ),
              ),
            ),
          ),

          // Danmaku overlay
          const DanmakuOverlay(),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + AppDimens.paddingSm,
            left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingLg),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Enter PIP mode if video is playing, then pop back.
                      final room = ref.read(liveProvider).room;
                      if (_videoController != null && _videoReady && room != null) {
                        ref.read(pipProvider.notifier).enterPip(_videoController!, room);
                      }
                      context.pop();
                    },
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: AppDimens.paddingMd),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _onAuthorTap,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.card,
                            backgroundImage: room.authorAvatar.isNotEmpty
                                ? CachedNetworkImageProvider(room.authorAvatar)
                                : null,
                            child: room.authorAvatar.isEmpty
                                ? Text(room.authorName.isNotEmpty ? room.authorName[0] : '?',
                                    style: const TextStyle(fontSize: 12, color: Colors.white))
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppDimens.paddingSm),
                        Flexible(
                          child: GestureDetector(
                            onTap: _onAuthorTap,
                            child: Text(
                              room.authorName,
                              style: AppTextStyles.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.paddingSm),
                        GestureDetector(
                          onTap: _onFollowTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingSm, vertical: 2),
                            decoration: BoxDecoration(
                              color: isFollowing ? Colors.black.withOpacity(0.1) : null,
                              border: Border.all(color: isFollowing ? AppColors.textHint : AppColors.divider),
                              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                            ),
                            child: Text(
                              isFollowing ? '已关注' : '关注',
                              style: TextStyle(
                                fontSize: 10,
                                color: isFollowing ? AppColors.textHint : AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.paddingSm),
                  // Heat value
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingSm, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(160),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                        const SizedBox(width: 2),
                        Text(state.heatCountText, style: const TextStyle(fontSize: 11, color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.paddingSm),
                  GestureDetector(
                    onTap: _showAudienceList,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingSm, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(state.onlineCountText, style: const TextStyle(fontSize: 12, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Connection status
          if (!state.isConnected)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingMd, vertical: AppDimens.paddingXs),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(200),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: const Text('连接中...', style: TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ),
            ),

          // Right action bar (like, comment, share, product)
          Positioned(
            right: AppDimens.paddingMd,
            bottom: 180 + bottomInset,
            child: _LiveRoomActionBar(
              likeCount: state.likeCount,
              isLiked: state.isLiked,
              onLike: () => ref.read(liveProvider.notifier).toggleLike(),
              onComment: _toggleChatInput,
              onShare: _onShare,
              onProduct: _showProductList,
              onGift: _showGiftPanel,
            ),
          ),

          // Comment list (scrollable, shows recent messages)
          Positioned(
            left: AppDimens.paddingMd,
            right: AppDimens.paddingLg + 56,
            bottom: 60 + bottomInset,
            height: 100,
            child: _CommentList(messages: state.messages),
          ),

          // Explaining product card
          if (state.currentProduct != null)
            Positioned(
              left: AppDimens.paddingLg,
              right: AppDimens.paddingLg,
              bottom: 160 + bottomInset,
              child: _ExplainingProductCard(
                product: state.currentProduct!,
                onTap: () => _showProductDetail(context, state.currentProduct!),
              ),
            ),

          // Coupon banners
          if (state.coupons.isNotEmpty)
            Positioned(
              left: AppDimens.paddingLg,
              right: AppDimens.paddingLg,
              bottom: state.currentProduct != null ? 220 + bottomInset : 160 + bottomInset,
              child: CouponCountdown(
                coupon: state.coupons.first,
                onClaim: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('优惠券已领取！'), backgroundColor: AppColors.success),
                  );
                },
              ),
            ),

          // Bottom chat bar
          Positioned(
            bottom: bottomInset,
            left: 0, right: AppDimens.paddingLg + 56,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.paddingLg, AppDimens.paddingSm, 0, AppDimens.paddingSm),
              child: SafeArea(
                top: false,
                child: _showChatInput
                    ? TextField(
                        controller: _chatController,
                        focusNode: _chatFocusNode,
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '说点什么...',
                          hintStyle: const TextStyle(color: AppColors.textHint),
                          filled: true,
                          fillColor: Colors.white.withAlpha(30),
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingMd, vertical: AppDimens.paddingSm),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send, color: AppColors.primary, size: 20),
                            onPressed: _sendMessage,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      )
                    : GestureDetector(
                        onTap: _toggleChatInput,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingMd, vertical: AppDimens.paddingSm + 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                          ),
                          child: const Text('说点什么...', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}

final class _LiveRoomActionBar extends StatelessWidget {
  const _LiveRoomActionBar({
    required this.likeCount,
    required this.isLiked,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onProduct,
    this.onGift,
  });

  final int likeCount;
  final bool isLiked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onProduct;
  final VoidCallback? onGift;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionItem(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          iconColor: isLiked ? AppColors.primary : null,
          label: likeCount > 0 ? likeCount.toString() : '点赞',
          onTap: onLike,
        ),
        const SizedBox(height: AppDimens.paddingLg),
        _ActionItem(
          icon: Icons.message,
          label: '评论',
          onTap: onComment,
        ),
        const SizedBox(height: AppDimens.paddingLg),
        _ActionItem(
          icon: Icons.share,
          label: '分享',
          onTap: onShare,
        ),
        const SizedBox(height: AppDimens.paddingLg),
        _ActionItem(
          icon: Icons.shopping_bag_outlined,
          label: '商品',
          onTap: onProduct,
        ),
        const SizedBox(height: AppDimens.paddingLg),
        _ActionItem(
          icon: Icons.card_giftcard,
          label: '礼物',
          onTap: onGift,
        ),
      ],
    );
  }
}

final class _ActionItem extends StatelessWidget {
  const _ActionItem({
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
          Icon(icon, size: 32, color: iconColor ?? Colors.white),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }
}

final class _ExplainingProductCard extends StatelessWidget {
  const _ExplainingProductCard({required this.product, this.onTap});

  final ProductModel product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.paddingSm),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(200),
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.accent.withAlpha(150)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              child: CachedNetworkImage(
                imageUrl: product.coverUrl, width: 56, height: 56, fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.card),
                errorWidget: (_, __, ___) => Container(color: AppColors.card),
              ),
            ),
            const SizedBox(width: AppDimens.paddingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppColors.accent, size: 14),
                      SizedBox(width: 4),
                      Text('主播正在讲解', style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(product.name, style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('¥${product.price.toStringAsFixed(0)}', style: AppTextStyles.priceSmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

final class _AuthorInfoSheet extends StatelessWidget {
  const _AuthorInfoSheet({
    required this.authorName,
    required this.authorAvatar,
    required this.authorId,
    this.onFollow,
    this.isFollowing = false,
  });

  final String authorName;
  final String authorAvatar;
  final String authorId;
  final VoidCallback? onFollow;
  final bool isFollowing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: AppDimens.paddingLg),
              decoration: BoxDecoration(color: AppColors.textHint, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.card,
            backgroundImage: authorAvatar.isNotEmpty ? CachedNetworkImageProvider(authorAvatar) : null,
            child: authorAvatar.isEmpty
                ? Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 28, color: Colors.white))
                : null,
          ),
          const SizedBox(height: AppDimens.paddingMd),
          Text(authorName, style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimens.paddingXs),
          Text('ID: $authorId', style: AppTextStyles.bodySmall),
          const SizedBox(height: AppDimens.paddingLg),
          SizedBox(
            width: 120,
            child: ElevatedButton(
              onPressed: onFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? AppColors.card : AppColors.primary,
                foregroundColor: isFollowing ? AppColors.textSecondary : Colors.white,
              ),
              child: Text(isFollowing ? '已关注' : '关注'),
            ),
          ),
          const SizedBox(height: AppDimens.paddingLg),
        ],
      ),
    );
  }
}

final class _CommentList extends StatelessWidget {
  const _CommentList({required this.messages});

  final List<LiveMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();

    // Show only the last 10 messages in the comment list
    final displayMessages = messages.length > 10
        ? messages.sublist(messages.length - 10)
        : messages;

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: displayMessages.length,
      itemBuilder: (context, index) {
        final msg = displayMessages[index];
        final isSystem = msg.isSystem;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.paddingXs),
          child: RichText(
            text: TextSpan(
              children: [
                if (!isSystem) ...[
                  TextSpan(
                    text: '${msg.userName} ',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 1, offset: Offset(1, 1))],
                    ),
                  ),
                ],
                TextSpan(
                  text: msg.content,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSystem ? AppColors.warning : Colors.white,
                    fontWeight: isSystem ? FontWeight.w600 : FontWeight.w400,
                    shadows: const [Shadow(color: Colors.black38, blurRadius: 1, offset: Offset(1, 1))],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
