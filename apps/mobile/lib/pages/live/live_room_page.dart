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
import '../../provider/auth_provider.dart';
import '../../provider/cart_provider.dart';
import '../../provider/favorite_provider.dart';
import '../../provider/follow_provider.dart';
import '../../provider/live_provider.dart';
import '../../provider/pip_provider.dart';
import '../../provider/user_provider.dart';
import '../../widgets/coupon_countdown.dart';
import '../../utils/toast.dart';
import '../../widgets/danmaku_overlay.dart';
import '../../widgets/floating_product_card.dart';
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
    // When returning from PIP we already have a video controller and room info
    // — mark initialized immediately so the spinner is skipped and the
    // PIP controller can be reused right away.
    final pipState = ref.read(pipProvider);
    final hasPip = pipState.videoController != null && pipState.roomInfo != null;
    if (hasPip) {
      _initialized = true;
    }
    Future.microtask(() {
      final rooms = ref.read(roomListProvider);
      final index = rooms.indexWhere((r) => r.id == widget.roomId);
      if (mounted) {
        setState(() {
          _currentIndex = index >= 0 ? index : 0;
          _initialized = true;
        });
        if (index >= 0) {
          _pageController.jumpToPage(index);
        }
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
    final liveState = ref.watch(liveProvider);
    final rooms = ref.watch(roomListProvider);

    if (rooms.isEmpty && !_initialized) {
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

    // When the room list is empty (e.g. returning from PIP), use the live
    // provider's room or the PIP room info as a single-item list so the
    // video player can be created immediately without waiting for the API.
    final pipState = ref.watch(pipProvider);
    final displayRooms = rooms.isNotEmpty
        ? rooms
        : (liveState.room != null
            ? [liveState.room!]
            : (pipState.videoController != null && pipState.roomInfo != null
                ? [pipState.roomInfo!]
                : <LiveRoomInfo>[]));

    if (displayRooms.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final safeIndex = _currentIndex.clamp(0, displayRooms.length - 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: displayRooms.length == 1
          ? _LiveRoomActiveContent(
              key: ValueKey('live_${displayRooms[0].id}'),
              room: displayRooms[0],
            )
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: displayRooms.length,
              onPageChanged: (index) {
                if (index >= 0 && index < displayRooms.length) {
                  setState(() => _currentIndex = index);
                  ref
                      .read(liveProvider.notifier)
                      .switchRoom(displayRooms[index].id);
                }
              },
              itemBuilder: (context, index) {
                final room = displayRooms[index];
                final isActive = index == safeIndex;
                if (isActive) {
                  return _LiveRoomActiveContent(
                      key: ValueKey('live_${room.id}'), room: room);
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
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    // If returning from PIP, reuse the already-initialized controller.
    final pipState = ref.read(pipProvider);
    if (!pipState.isActive && pipState.videoController != null) {
      _videoController = pipState.videoController;
      _videoReady = true;
      _videoError = false;
      _videoController!.play();
      // Take ownership — release the PIP reference without disposing.
      ref.read(pipProvider.notifier).releaseController();
      return;
    }
    _initVideo(widget.room.videoUrl);
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

  /// Initialize (or re-initialize) the video player.
  /// Safe to call multiple times — returns early if already initializing.
  void _initVideo(String url) {
    if (url.isEmpty) {
      debugPrint('[LiveRoom] video URL is empty — room data may not have loaded yet');
      if (mounted) setState(() => _videoError = true);
      return;
    }
    // If we already have a working controller, don't re-init.
    if (_videoController != null && _videoReady) return;
    // Dispose any failed/previous controller first.
    if (_videoController != null) {
      _videoController!.dispose();
      _videoController = null;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      debugPrint('[LiveRoom] invalid video URL: $url');
      if (mounted) setState(() => _videoError = true);
      return;
    }

    setState(() {
      _videoReady = false;
      _videoError = false;
    });

    debugPrint('[LiveRoom] initializing video: $url');
    final controller = VideoPlayerController.networkUrl(uri);
    _videoController = controller;
    controller.initialize().then((_) {
      if (!mounted || _videoController != controller) return;
      setState(() {
        _videoReady = true;
        _videoError = false;
      });
      controller.setLooping(true);
      controller.play();
    }).catchError((Object err) {
      debugPrint('[LiveRoom] video init error: $err');
      if (!mounted || _videoController != controller) return;
      setState(() => _videoError = true);
      controller.dispose();
      if (_videoController == controller) _videoController = null;
    });
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
    final audiences = _generateAudiences(state.onlineCount);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AudienceList(
        audiences: audiences,
        onlineCount: state.onlineCount,
      ),
    );
  }

  /// Generate a realistic mock audience list based on the online count.
  /// Shows up to ~30 users — a mix of known seed users and random viewers.
  List<Audience> _generateAudiences(int onlineCount) {
    // Known "seed" users that appear in most live rooms.
    const known = [
      ('u2', '小明数码'),
      ('u3', '小红穿搭'),
      ('u4', '阿杰户外'),
      ('u5', '数码控小王'),
    ];

    // Random viewer name parts for natural-looking names.
    const prefixes = ['观众', '粉丝', '用户', '网友', '买家', '路人'];
    const suffixes = [
      '小明', '小红', '阿杰', '小王', '阿花', '小美', '大壮', '老李',
      '小陈', '阿强', '张三', '李四', '王五', '赵六', '七七', '八哥',
      '小柒', '阿星', '大刘', '老周', '小吴', '阿林', '阿辉', '菜菜',
      '球球', '豆豆', '米粒', '糖糖', '果果', '乐乐', '星星', '月亮',
    ];

    final list = <Audience>[];
    final rand = DateTime.now().millisecondsSinceEpoch; // pseudo-random seed

    // Always show the known users first (if they fit).
    final knownCount = (onlineCount >= 5) ? known.length : (onlineCount > 0 ? 1 : 0);
    for (int i = 0; i < knownCount; i++) {
      list.add(Audience(
        userId: known[i].$1,
        name: known[i].$2,
        avatar: '',
      ));
    }

    // Fill up to min(onlineCount, 30) with random viewers.
    final maxShow = (onlineCount.clamp(0, 30)) - list.length;
    for (int i = 0; i < maxShow; i++) {
      final prefix = prefixes[(rand + i * 7) % prefixes.length];
      final suffix = suffixes[(rand + i * 13) % suffixes.length];
      final num = (rand + i * 17 + 1000) % 10000; // 1000-10999
      list.add(Audience(
        userId: 'viewer_${num}_$i',
        name: '$prefix$suffix$num',
        avatar: '',
      ));
    }

    return list;
  }

  void _showGiftPanel() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GiftPanel(
        onSelect: (gift) {
          Navigator.of(context).pop();
          _sendGiftWithCoin(gift);
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _sendGiftWithCoin(Gift gift) async {
    final auth = ref.read(authProvider);
    final userState = ref.read(userProvider);
    final room = ref.read(liveProvider).room;

    if (!auth.isLoggedIn || auth.userId == null) {
      showToast('请先登录', type: ToastType.warning);
      return;
    }

    if (room == null) return;

    // 检查余额是否足够（前端预检）
    if (userState.coinBalance < gift.price) {
      _showGiftInsufficientBalanceDialog(gift.price);
      return;
    }

    try {
      final api = ref.read(liveApiProvider);
      final result = await api.sendGift(
        userId: auth.userId!,
        giftId: gift.id,
        giftName: gift.name,
        price: gift.price,
        roomId: room.id,
      );

      // 更新本地余额
      final newBalance = (result['new_balance'] as num).toDouble();
      ref.read(userProvider.notifier).updateCoinBalance(newBalance);

      // 发送礼物弹幕
      ref.read(liveProvider.notifier).sendGift('我', gift.icon, gift.name);

      showToast('送出 ${gift.icon} ${gift.name}', type: ToastType.success);
    } catch (e) {
      // 余额不足的错误（服务端返回 422）
      if (e.toString().contains('422') || e.toString().contains('余额不足')) {
        _showGiftInsufficientBalanceDialog(gift.price);
      } else {
        showToast('发送礼物失败，请重试', type: ToastType.error);
      }
    }
  }

  void _showGiftInsufficientBalanceDialog(int requiredCoins) {
    final userState = ref.read(userProvider);
    final diff = (requiredCoins - userState.coinBalance).ceil();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFFA500), size: 24),
            SizedBox(width: AppDimens.paddingSm),
            Text('抖币不足', style: AppTextStyles.titleMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前抖币余额：${userState.coinBalance.toStringAsFixed(0)} 抖币',
              style: AppTextStyles.bodyLarge,
            ),
            const SizedBox(height: AppDimens.paddingSm),
            Text(
              '还需充值约：$diff 抖币',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimens.paddingMd),
            Container(
              padding: const EdgeInsets.all(AppDimens.paddingSm),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.card_giftcard, size: 16, color: Color(0xFFFFA500)),
                  SizedBox(width: AppDimens.paddingSm),
                  Text(
                    '充值有额外赠送抖币',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFFFA500),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消', style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AppRouter.router.pushNamed(
                'coinRecharge',
                queryParameters: <String, String>{
                  'from': 'gift',
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
            child: const Text('去充值', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Returns the best available room for PIP entry — live state first,
  /// falling back to the widget prop (e.g. when returning from PIP).
  LiveRoomInfo get _currentRoom =>
      ref.read(liveProvider).room ?? widget.room;

  void _showProductDetail(BuildContext context, ProductModel product) {
    final favState = ref.read(favoriteProvider);
    showProductDetailSheet(
      context: context,
      product: product,
      onAddToCart: (spec, quantity, couponId) {
        ref.read(cartProvider.notifier).addToCart(
          productId: product.id,
          spec: spec,
          quantity: quantity,
        );
      },
      onBuyNow: (spec, quantity, couponId) {
        // Dismiss the product detail bottom sheet first.
        Navigator.of(context).pop();
        // Enter PIP mode before navigating away so the live stream keeps playing.
        if (_videoController != null && _videoReady) {
          ref.read(pipProvider.notifier).enterPip(_videoController!, _currentRoom);
        }
        // Use the global router — context from inside a bottom sheet is stale after pop.
        AppRouter.router.pushNamed('orderConfirm', queryParameters: <String, String>{
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveProvider);
    final followState = ref.watch(followProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // When returning from PIP we may have video playing but state.room
    // hasn't loaded yet — use widget.room as fallback so the UI renders
    // immediately instead of showing a spinner or error.
    final effectiveRoom = state.room ?? widget.room;
    final hasVideo = _videoController != null && _videoReady;

    // Only show full-screen error when we have no video at all.
    if (!hasVideo && state.errorMessage != null && !state.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.textHint),
              const SizedBox(height: AppDimens.paddingMd),
              Text(state.errorMessage!, style: AppTextStyles.titleMedium),
              const SizedBox(height: AppDimens.paddingLg),
              ElevatedButton(
                onPressed: () =>
                    ref.read(liveProvider.notifier).enterRoom(widget.room.id),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    // effectiveRoom is always non-null (widget.room is required) so we
    // always have enough data to render the UI — even before state loads.
    final room = effectiveRoom;
    final isFollowing = followState.followingIds.contains(room.authorId);

    return PopScope(
      canPop: false, // We handle back navigation ourselves.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Enter PIP mode if video is playing, then pop.
        final currentRoom = _currentRoom;
        if (_videoController != null && _videoReady) {
          ref.read(pipProvider.notifier).enterPip(_videoController!, currentRoom);
        }
        context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: video player / cover image / error.
          // Wrapped in IgnorePointer so the Android SurfaceView doesn't
          // consume vertical drag events — the outer PageView needs them.
          if (_videoController != null && _videoReady) ...[
            IgnorePointer(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _videoController!,
                builder: (_, value, __) {
                  if (!value.isInitialized || value.size.isEmpty) {
                    return CachedNetworkImage(
                      imageUrl: room.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.surface),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.surface),
                    );
                  }
                  return FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: value.size.width,
                      height: value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  );
                },
              ),
            ),
            // No play/pause tap layer for live streaming — the stream
            // should play continuously and not be user-pausable.
            // The video is wrapped in IgnorePointer so vertical
            // drags pass through to the outer PageView.
          ],

          // Video-fallback layer (only when no active video).
          if (!_videoReady && _videoError)
            Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: room.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: AppColors.surface),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppColors.surface),
                ),
                Container(color: Colors.black54),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_outline,
                          size: 56, color: Colors.white54),
                      const SizedBox(height: AppDimens.paddingSm),
                      const Text('视频加载失败',
                          style: TextStyle(
                              fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: AppDimens.paddingLg),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _initVideo(widget.room.videoUrl),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('重新加载'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          if (!_videoReady && !_videoError)
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

          // Bottom gradient — only behind the input row.
          Positioned(
            bottom: 0, left: 0, right: 0, height: 64 + bottomInset,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withAlpha(180), Colors.transparent],
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
                      if (_videoController != null && _videoReady) {
                        ref.read(pipProvider.notifier).enterPip(
                            _videoController!, _currentRoom);
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

          // Comments (left side, above bottom row) + Product card (right side)
          Builder(builder: (ctx) {
            final hasProduct =
                state.currentProduct != null || state.products.isNotEmpty;
            final screenW = MediaQuery.of(context).size.width;
            final cardW = hasProduct ? screenW / 3 : 0.0;
            const bottomRowH = 48.0;
            return Stack(
              children: [
                // Comments — left side, same height as product card
                Positioned(
                  left: AppDimens.paddingMd,
                  right: hasProduct
                      ? cardW + AppDimens.paddingSm
                      : AppDimens.paddingLg + 56,
                  bottom: bottomRowH + AppDimens.paddingSm + bottomInset,
                  height: 180,
                  child: _CommentList(messages: state.messages),
                ),
                // Product card — right side, bottom at bottom-row top
                if (hasProduct)
                  Positioned(
                    right: AppDimens.paddingMd,
                    bottom: bottomRowH + AppDimens.paddingSm + bottomInset,
                    width: cardW - AppDimens.paddingSm,
                    height: 180,
                    child: FloatingProductCard(
                      product: state.currentProduct ??
                          state.products.first,
                      onTap: () => _showProductDetail(
                          ctx,
                          state.currentProduct ??
                              state.products.first),
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      disableAutoFade: true,
                      verticalLayout: true,
                    ),
                  ),
              ],
            );
          }),

          // Coupon banners
          if (state.coupons.isNotEmpty)
            Positioned(
              left: AppDimens.paddingLg,
              right: AppDimens.paddingLg,
              bottom: 200 + bottomInset,
              child: CouponCountdown(
                coupon: state.coupons.first,
                onClaim: () {
                showToast('优惠券已领取！', type: ToastType.success);
                },
              ),
            ),

          // ---- Bottom row: input (left 1/2) + actions (right 1/2) ----
          Positioned(
            bottom: bottomInset,
            left: 0,
            right: 0,
            child: Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: AppDimens.paddingSm),
              child: Row(
                children: [
                  // Input — left half
                  Expanded(
                    flex: 1,
                    child: _showChatInput
                        ? TextField(
                            controller: _chatController,
                            focusNode: _chatFocusNode,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: '说点什么...',
                              hintStyle: const TextStyle(
                                  color: AppColors.textHint, fontSize: 13),
                              filled: true,
                              fillColor: Colors.white.withAlpha(25),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send,
                                    color: AppColors.primary, size: 18),
                                onPressed: _sendMessage,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          )
                        : GestureDetector(
                            onTap: _toggleChatInput,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(25),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Text('说点什么...',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textHint)),
                            ),
                          ),
                  ),
                  const SizedBox(width: AppDimens.paddingXs),
                  // Action buttons — right half
                  _BottomActionBtn(
                    icon: Icons.shopping_cart_outlined,
                    onTap: () {
                      // Enter PIP before navigating to cart.
                      if (_videoController != null && _videoReady) {
                        ref
                            .read(pipProvider.notifier)
                            .enterPip(_videoController!, _currentRoom);
                      }
                      AppRouter.router.go('/cart');
                    },
                  ),
                  _BottomActionBtn(
                    icon: state.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    iconColor:
                        state.isLiked ? AppColors.primary : Colors.white70,
                    label: state.likeCount > 0
                        ? state.likeCount.toString()
                        : null,
                    onTap: () =>
                        ref.read(liveProvider.notifier).toggleLike(),
                  ),
                  _BottomActionBtn(
                    icon: Icons.card_giftcard,
                    onTap: _showGiftPanel,
                  ),
                  _BottomActionBtn(
                    icon: Icons.ios_share,
                    onTap: _onShare,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}

/// Compact action button for the bottom row.
final class _BottomActionBtn extends StatelessWidget {
  const _BottomActionBtn({
    required this.icon,
    this.iconColor,
    this.label,
    this.onTap,
  });

  final IconData icon;
  final Color? iconColor;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: iconColor ?? Colors.white70),
            if (label != null) ...[
              const SizedBox(height: 1),
              Text(label!, style: const TextStyle(fontSize: 9, color: Colors.white60)),
            ],
          ],
        ),
      ),
    );
  }
}

final class _AuthorInfoSheet extends ConsumerWidget {
  const _AuthorInfoSheet({
    required this.authorName,
    required this.authorAvatar,
    required this.authorId,
    this.onFollow,
  });

  final String authorName;
  final String authorAvatar;
  final String authorId;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read follow state directly from provider so the sheet reacts
    // to state changes immediately (fixes "点击关注后不变" bug).
    final isFollowing =
        ref.watch(followProvider).followingIds.contains(authorId);
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

/// Simple inline comment list widget for live room.
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
