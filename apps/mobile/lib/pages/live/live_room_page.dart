import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_constants.dart';
import '../../models/product_model.dart';
import '../../provider/cart_provider.dart';
import '../../provider/follow_provider.dart';
import '../../provider/live_provider.dart';
import '../../utils/toast.dart';
import '../../widgets/coupon_countdown.dart';
import '../../widgets/danmaku_overlay.dart';
import '../../widgets/product_detail_sheet.dart';
import '../../widgets/product_floating_card.dart';
import 'audience_list.dart';
import 'gift_panel.dart';

final class LiveRoomPage extends ConsumerStatefulWidget {
  const LiveRoomPage({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<LiveRoomPage> createState() => _LiveRoomPageState();
}

final class _LiveRoomPageState extends ConsumerState<LiveRoomPage> {
  final _chatController = TextEditingController();
  final _chatFocusNode = FocusNode();
  bool _showChatInput = false;
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(liveProvider.notifier).enterRoom(widget.roomId);
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatFocusNode.dispose();
    _releaseVideo();
    ref.read(liveProvider.notifier).leaveRoom();
    super.dispose();
  }

  void _releaseVideo() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
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
    } on Exception {
      // toast handled in provider
    }
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveProvider);
    final followState = ref.watch(followProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    if (state.isLoading || state.room == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (state.errorMessage != null && state.room == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppDimens.paddingMd),
              Text(state.errorMessage!, style: AppTextStyles.bodyMedium),
              const SizedBox(height: AppDimens.paddingLg),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    final room = state.room!;
    final isFollowing = followState.followingIds.contains(room.authorId);

    if (room.videoUrl.isNotEmpty && _videoController == null) {
      _initVideo(room.videoUrl);
    }

    return Scaffold(
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
              placeholder: (context, url) => Container(color: AppColors.surface),
              errorWidget: (context, url, error) => Container(color: AppColors.surface),
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
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: AppDimens.paddingMd),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.card,
                          child: Text(
                            room.authorName.isNotEmpty ? room.authorName[0] : '?',
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: AppDimens.paddingSm),
                        Flexible(
                          child: Text(
                            room.authorName,
                            style: AppTextStyles.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                  // Online count
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
                          Text(
                            state.onlineCountText,
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
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

          if (state.currentProduct != null)
            Positioned(
              right: AppDimens.paddingLg,
              bottom: bottomInset + 80 + AppDimens.paddingMd,
              child: _FloatingProductCard(
                product: state.currentProduct!,
                onTap: () {
                  showProductDetailSheet(
                    context: context,
                    product: state.currentProduct!,
                    onAddToCart: () {
                      ref.read(cartProvider.notifier).addToCart(
                        productId: state.currentProduct!.id,
                      );
                    },
                    onBuyNow: () {
                      final p = state.currentProduct!;
                      context.pushNamed('orderConfirm', queryParameters: <String, String>{
                        'from': 'buy_now',
                        'total': p.price.toString(),
                        'count': '1',
                        'product_id': p.id,
                        'product_name': p.name,
                        'product_price': p.price.toString(),
                        'product_cover': p.coverUrl,
                        'product_spec': '',
                        'quantity': '1',
                      });
                    },
                  );
                },
              ),
            )
          else if (state.products.isNotEmpty)
            Positioned(
              right: AppDimens.paddingLg,
              bottom: bottomInset + 80 + AppDimens.paddingMd,
              child: _FloatingProductCard(
                product: state.products.first,
                onTap: () {
                  final product = state.products.first;
                  showProductDetailSheet(
                    context: context,
                    product: product,
                    onAddToCart: () {
                      ref.read(cartProvider.notifier).addToCart(
                        productId: product.id,
                      );
                    },
                    onBuyNow: () {
                      final p = product;
                      context.pushNamed('orderConfirm', queryParameters: <String, String>{
                        'from': 'buy_now',
                        'total': p.price.toString(),
                        'count': '1',
                        'product_id': p.id,
                        'product_name': p.name,
                        'product_price': p.price.toString(),
                        'product_cover': p.coverUrl,
                        'product_spec': '',
                        'quantity': '1',
                      });
                    },
                  );
                },
              ),
            ),

          // Explaining product card
          if (state.currentProduct != null)
            Positioned(
              left: AppDimens.paddingLg,
              bottom: 160 + bottomInset,
              right: 100,
              child: _ExplainingProductCard(
                product: state.currentProduct!,
                onTap: () {
                  showProductDetailSheet(
                    context: context,
                    product: state.currentProduct!,
                    onAddToCart: () {
                      ref.read(cartProvider.notifier).addToCart(productId: state.currentProduct!.id);
                    },
                    onBuyNow: () {
                      final p = state.currentProduct!;
                      context.pushNamed('orderConfirm', queryParameters: <String, String>{
                        'from': 'buy_now',
                        'total': p.price.toString(),
                        'count': '1',
                        'product_id': p.id,
                        'product_name': p.name,
                        'product_price': p.price.toString(),
                        'product_cover': p.coverUrl,
                        'product_spec': '',
                        'quantity': '1',
                      });
                    },
                  );
                },
              ),
            ),

          // Coupon banners
          if (state.coupons.isNotEmpty)
            Positioned(
              left: AppDimens.paddingLg,
              bottom: state.currentProduct != null ? 220 + bottomInset : 160 + bottomInset,
              right: AppDimens.paddingLg,
              child: CouponCountdown(
                coupon: state.coupons.first,
                onClaim: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('优惠券已领取！'), backgroundColor: AppColors.success),
                  );
                },
              ),
            ),

          // Bottom bar
          Positioned(
            bottom: bottomInset,
            left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.paddingLg, AppDimens.paddingSm, AppDimens.paddingLg, AppDimens.paddingSm),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: AppDimens.paddingMd),
                    _BottomAction(icon: Icons.shopping_bag_outlined, label: '商品', onTap: () => _showProductList(context)),
                    const SizedBox(width: AppDimens.paddingSm),
                    _BottomAction(icon: Icons.share, label: '分享', onTap: _onShare),
                    const SizedBox(width: AppDimens.paddingSm),
                    _BottomAction(icon: Icons.card_giftcard, label: '礼物', onTap: _showGiftPanel),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductList(BuildContext context) {
    final products = ref.read(liveProvider).products;

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
                            showProductDetailSheet(
                              context: context,
                              product: product,
                              onAddToCart: () {
                                ref.read(cartProvider.notifier).addToCart(productId: product.id);
                              },
                              onBuyNow: () {
                                final p = product;
                                context.pushNamed('orderConfirm', queryParameters: <String, String>{
                                  'from': 'buy_now',
                                  'total': p.price.toString(),
                                  'count': '1',
                                  'product_id': p.id,
                                  'product_name': p.name,
                                  'product_price': p.price.toString(),
                                  'product_cover': p.coverUrl,
                                  'product_spec': '',
                                  'quantity': '1',
                                });
                              },
                            );
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

final class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _FloatingProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final Duration delay;

  const _FloatingProductCard({
    required this.product,
    this.onTap,
    this.delay = const Duration(milliseconds: 500),
  });

  @override
  State<_FloatingProductCard> createState() => _FloatingProductCardState();
}

class _FloatingProductCardState extends State<_FloatingProductCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0), // 从右侧滑入
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // 延时显示
    _startDelayTimer();
  }

  void _startDelayTimer() {
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕宽度的三分之一
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth / 3;

    // 如果还没到显示时间，返回空容器
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: SlideTransition(
            position: _slideAnimation,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 商品图片
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 1, // 正方形图片
                  child: Image.network(
                    widget.product.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey,
                              size: 32,
                            ),
                            SizedBox(height: 4),
                            Text(
                              '暂无图片',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 商品名称
              Text(
                widget.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 4),

              // 价格行
              Row(
                children: [
                  // 当前价格
                  Text(
                    '¥${widget.product.price}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF4759),
                    ),
                  ),

                  // 原价（如果有优惠）
                  if (widget.product.originalPrice > widget.product.price) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '¥${widget.product.originalPrice}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF999999),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // 可选：销量信息
              if (widget.product.sales > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '已售${_formatSales(widget.product.sales)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 格式化销量数字
  String _formatSales(int sales) {
    if (sales >= 10000) {
      return '${(sales / 10000).toStringAsFixed(1)}万';
    } else if (sales >= 1000) {
      return '${(sales / 1000).toStringAsFixed(1)}k';
    }
    return sales.toString();
  }
}
