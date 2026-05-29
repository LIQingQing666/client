import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/product_api.dart';
import '../../core/app_constants.dart';
import '../../models/product_model.dart';
import '../../models/video_model.dart';
import '../../provider/cart_provider.dart';
import '../../provider/feed_provider.dart';
import '../../provider/follow_provider.dart';
import '../../provider/service_providers.dart';
import '../../utils/toast.dart';
import '../../widgets/product_detail_sheet.dart';
import '../../widgets/video_comments_sheet.dart';
import '../../widgets/video_player_widget.dart';
import '../../widgets/product_floating_card.dart';

final class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key, this.initialVideoId});

  final String? initialVideoId;

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

final class _FeedPageState extends ConsumerState<FeedPage> {
  late final PageController _pageController = PageController();
  final ValueNotifier<int> _seekTrigger = ValueNotifier<int>(0);
  String? _pendingJumpVideoId;
  ProductModel? _currentProduct;
  bool _isProductCardVisible = false;
  bool _isInitialLoad = true;

  //load product information and set product_card
  Future<void> _loadCurrentVideoProduct(VideoModel video) async {
    // 重置状态
    if (mounted) {
      setState(() {
        _currentProduct = null;
        _isProductCardVisible = false;
      });
    }

    try {
      // 通过 videoApi 获取视频详情，其中包含商品列表
      final videoApi = ref.read(videoApiProvider);
      final detail = await videoApi.getVideoDetail(video.id);

      if (!mounted) return;

      // detail.products 是 List<Map<String, dynamic>>
      final products = detail.products;
      if (products.isNotEmpty) {
        setState(() {
          _currentProduct = ProductModel.fromJson(products.first);
          _isProductCardVisible = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to load product for video ${video.id}: $e');
      // 静默处理，不影响视频播放
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialVideoId != null) {
      _pendingJumpVideoId = widget.initialVideoId;
    }

    // 初始加载第一个视频的商品
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final feedState = ref.read(feedProvider);
      if (feedState.videos.isNotEmpty) {
        _loadCurrentVideoProduct(feedState.videos.first);
      }
    });
  }

  @override
  void dispose() {
    _seekTrigger.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onProductTap(VideoModel video) async {
    final videoApi = ref.read(videoApiProvider);
    try {
      final detail = await videoApi.getVideoDetail(video.id);
      final products = detail.products;
      if (products.isEmpty || !mounted) return;

      final product = ProductModel.fromJson(products.first);
      if (!mounted) return;

      await showProductDetailSheet(
        context: context,
        product: product,
        onAddToCart: () {
          ref.read(cartProvider.notifier).addToCart(productId: product.id);
        },
        onBuyNow: () {
          context.pushNamed('orderConfirm', queryParameters: <String, String>{
            'from': 'buy_now',
            'total': product.price.toString(),
            'count': '1',
            'product_id': product.id,
            'product_name': product.name,
            'product_price': product.price.toString(),
            'product_cover': product.coverUrl,
            'product_spec': '',
            'quantity': '1',
          });
        },
        onSeekToTime: product.highlightTime > 0
            ? () {
                _seekTrigger.value = product.highlightTime;
                Navigator.of(context).pop();
              }
            : null,
        onRefreshAi: () async {
          final api = ProductApi(client: ref.read(dioClientProvider));
          try {
            final newPoint = await api.getAiSalesPoint(product.id);
            if (!mounted) return;
            Navigator.of(context).pop();
            final updated = ProductModel(
              id: product.id, name: product.name, description: product.description,
              coverUrl: product.coverUrl, images: product.images,
              price: product.price, originalPrice: product.originalPrice,
              stock: product.stock, sales: product.sales,
              category: product.category, tags: product.tags,
              specs: product.specs, videoId: product.videoId,
              aiSalesPoint: newPoint, highlightTime: product.highlightTime,
            );
            if (!mounted) return;
            await showProductDetailSheet(
              context: context,
              product: updated,
              onAddToCart: () {
                ref.read(cartProvider.notifier).addToCart(productId: product.id);
              },
              onBuyNow: () {
                context.pushNamed('orderConfirm', queryParameters: <String, String>{
                  'from': 'buy_now',
                  'total': product.price.toString(),
                  'count': '1',
                  'product_id': product.id,
                  'product_name': product.name,
                  'product_price': product.price.toString(),
                  'product_cover': product.coverUrl,
                  'product_spec': '',
                  'quantity': '1',
                });
              },
              onSeekToTime: updated.highlightTime > 0
                  ? () {
                      _seekTrigger.value = updated.highlightTime;
                      Navigator.of(context).pop();
                    }
                  : null,
            );
          } on Exception {
            showToast('AI 卖点生成失败，请重试');
          }
        },
      );
    } on Exception {
      showToast('加载商品信息失败');
    }
  }

  Future<void> _onFollowTap(String authorId) async {
    try {
      await ref.read(followProvider.notifier).toggleFollow(authorId);
    } on Exception {
      // toast handled in provider
    }
  }

  void _onShare(VideoModel video) {
    Share.share('${video.title}\n\n一起来看精彩视频！');
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final notifier = ref.read(feedProvider.notifier);
    final pool = ref.read(playerPoolProvider);
    final followState = ref.watch(followProvider);
    final tabIndex = ref.watch(currentTabIndexProvider);
    final isTabActive = tabIndex == 0;
    final currentTab = feedState.tab;

    if (feedState.isLoading && feedState.videos.isEmpty) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (feedState.errorMessage != null && feedState.videos.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.textHint),
              const SizedBox(height: AppDimens.paddingMd),
              const Text('网络异常，请检查连接', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppDimens.paddingLg),
              ElevatedButton(
                onPressed: notifier.loadVideos,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    // Handle pending jump to specific video
    if (_pendingJumpVideoId != null && feedState.videos.isNotEmpty) {
      final targetIndex = feedState.videos.indexWhere((v) => v.id == _pendingJumpVideoId);
      if (targetIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.jumpToPage(targetIndex);
        });
      }
      _pendingJumpVideoId = null;
    }

    if (feedState.videos.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            currentTab == FeedTab.follow ? '还没有关注任何人，去看看推荐吧' : '暂无视频',
            style: AppTextStyles.titleMedium,
          ),
        ),
      );
    }

    if (_isInitialLoad && feedState.videos.isNotEmpty) {
      _isInitialLoad = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCurrentVideoProduct(feedState.videos[feedState.currentIndex]);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: feedState.videos.length + (feedState.hasMore ? 1 : 0),
            onPageChanged: (index) {
              if (index < feedState.videos.length) {
                notifier.setCurrentIndex(index);
              }
              _loadCurrentVideoProduct(feedState.videos[index]);
            },
            itemBuilder: (context, index) {
              if (index >= feedState.videos.length) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              final video = feedState.videos[index];
              final isActive = isTabActive && index == feedState.currentIndex;
              final isFollowing = followState.followingIds.contains(video.authorId);

              return VideoPlayerWidget(
                key: ValueKey(video.id),
                video: video,
                pool: pool,
                isActive: isActive,
                onLike: () => notifier.toggleLike(video.id),
                onProductTap: () => _onProductTap(video),
                onShare: () => _onShare(video),
                onMessage: () => showVideoCommentsSheet(
                  context: context,
                  videoId: video.id,
                ),
                onFollow: () => _onFollowTap(video.authorId),
                isFollowing: isFollowing,
                seekTrigger: _seekTrigger,
                productCard: _buildProductCard(),
              );
            },
          ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + AppDimens.paddingSm,
            left: 0,
            right: 0,
            child: Row(
              children: [
                const SizedBox(width: AppDimens.paddingLg),
                _TabButton(
                  label: '推荐',
                  isActive: currentTab == FeedTab.recommend,
                  onTap: () => notifier.switchTab(FeedTab.recommend),
                ),
                const SizedBox(width: AppDimens.paddingLg),
                _TabButton(
                  label: '关注',
                  isActive: currentTab == FeedTab.follow,
                  onTap: () => notifier.switchTab(FeedTab.follow),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search, color: AppColors.textPrimary),
                  onPressed: () => context.pushNamed('search'),
                ),
                IconButton(
                  icon: const Icon(Icons.mail_outline, color: AppColors.textPrimary),
                  onPressed: () => context.pushNamed('messages'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 确保方法有正确的缩进和括号匹配
  Widget? _buildProductCard() {
    if (!_isProductCardVisible || _currentProduct == null) {
      return null;
    }

    final feedState = ref.read(feedProvider);
    if (feedState.videos.isEmpty) return null;

    final currentVideo = feedState.videos[feedState.currentIndex];

    return ProductFloatingCard(
      product: _currentProduct!,
      delay: const Duration(milliseconds: 500),
      onTap: () {
        _onProductTap(currentVideo);
      },
    );
  }
}

final class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.isActive, required this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          fontSize: 18,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          color: isActive ? AppColors.textPrimary : AppColors.textHint,
        ),
        child: Text(label),
      ),
    );
  }
}
