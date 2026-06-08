import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../models/product_model.dart';
import '../../provider/cart_provider.dart';
import '../../provider/favorite_provider.dart';
import '../../provider/service_providers.dart';
import '../../widgets/product_detail_sheet.dart';

final class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

final class _FavoritesPageState extends ConsumerState<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoriteProvider);
    final videos = state.videos;
    final products = state.products;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          tabs: [
            Tab(text: '视频 (${videos.length})'),
            Tab(text: '商品 (${products.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVideoList(videos),
          _buildProductList(products),
        ],
      ),
    );
  }

  Widget _buildVideoList(List<FavoriteItem> videos) {
    if (videos.isEmpty) {
      return const Center(
        child: Text('暂无收藏视频', style: AppTextStyles.bodyMedium),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final item = videos[index];
        return _FavoriteVideoTile(
          item: item,
          onTap: () => context.pushNamed('singleVideo', pathParameters: {'videoId': item.id}),
          onRemove: () => ref.read(favoriteProvider.notifier).removeFavorite(item.id),
        );
      },
    );
  }

  Widget _buildProductList(List<FavoriteItem> products) {
    if (products.isEmpty) {
      return const Center(
        child: Text('暂无收藏商品', style: AppTextStyles.bodyMedium),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final item = products[index];
        return _FavoriteProductTile(
          item: item,
          onTap: () async {
            // Fetch fresh product data from API so highlight_time,
            // video_id, specs, etc. are always up to date.
            final productApi = ref.read(productApiProvider);
            ProductModel product;
            try {
              final detail = await productApi.getProductDetail(item.id);
              product = detail.product;
            } catch (_) {
              // Fallback: use stored data if API is unavailable.
              final raw = item.rawData;
              product = ProductModel(
                id: item.id,
                name: item.title,
                description: '',
                coverUrl: item.coverUrl,
                images: [item.coverUrl],
                price: double.tryParse(item.subtitle.replaceFirst('¥', '')) ?? 0,
                originalPrice: 0,
                stock: 0,
                sales: 0,
                category: '',
                tags: [],
                specs: [],
                videoId: (raw['video_id'] as String?) ?? '',
                aiSalesPoint: '',
                highlightTime: (raw['highlight_time'] as num?)?.toInt() ?? 0,
              );
            }
            if (!mounted) return;
            showProductDetailSheet(
              context: context,
              product: product,
              onAddToCart: (spec, quantity, couponId) {
                Navigator.of(context).pop();
                ref.read(cartProvider.notifier).addToCart(
                  productId: product.id,
                  spec: spec,
                  quantity: quantity,
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
              onSeekToTime: product.videoId.isNotEmpty
                  ? (seekTime) async {
                      // Close the bottom sheet and wait for its exit
                      // animation to complete before pushing the new route.
                      Navigator.of(context).pop();
                      // Small delay ensures the sheet is fully dismissed.
                      await Future.delayed(const Duration(milliseconds: 200));
                      if (!context.mounted) return;
                      context.pushNamed('singleVideo',
                          pathParameters: {'videoId': product.videoId},
                          queryParameters: seekTime > 0
                              ? {'seek': seekTime.toString()}
                              : {});
                    }
                  : null,
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
              isFavorited: true,
            );
          },
          onRemove: () => ref.read(favoriteProvider.notifier).removeFavorite(item.id),
        );
      },
    );
  }
}

final class _FavoriteVideoTile extends StatelessWidget {
  const _FavoriteVideoTile({required this.item, this.onTap, this.onRemove});

  final FavoriteItem item;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  String? get _authorAvatar {
    final v = item.rawData['author_avatar'] as String?;
    return (v != null && v.isNotEmpty) ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingLg,
          vertical: AppDimens.paddingXs,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                child: CachedNetworkImage(
                  imageUrl: item.coverUrl,
                  width: 56, height: 72, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 56, height: 72, color: AppColors.surface,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 56, height: 72, color: AppColors.surface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title + author
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLarge),
                    const SizedBox(height: 8),
                    // Author row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 10, backgroundColor: AppColors.divider,
                          backgroundImage: isNetworkImageUrl(_authorAvatar)
                              ? CachedNetworkImageProvider(_authorAvatar!)
                              : null,
                          child: !isNetworkImageUrl(_authorAvatar)
                              ? Text(
                                  item.subtitle.isNotEmpty ? item.subtitle[0] : '?',
                                  style: const TextStyle(fontSize: 9, color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text(item.subtitle, style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite_border, color: AppColors.textSecondary, size: 22),
                    onPressed: onTap,
                    tooltip: '查看视频',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark, color: AppColors.primary, size: 22),
                    onPressed: onRemove,
                    tooltip: '取消收藏',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _FavoriteProductTile extends StatelessWidget {
  const _FavoriteProductTile({required this.item, this.onTap, this.onRemove});

  final FavoriteItem item;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingLg,
        vertical: AppDimens.paddingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          child: CachedNetworkImage(
            imageUrl: item.coverUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 56, height: 56, color: AppColors.surface,
            ),
            errorWidget: (_, __, ___) => Container(
              width: 56, height: 56, color: AppColors.surface,
            ),
          ),
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyLarge),
        subtitle: Text(item.subtitle,
            style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600)),
        trailing: IconButton(
          icon: const Icon(Icons.bookmark, color: AppColors.primary),
          onPressed: onRemove,
          tooltip: '取消收藏',
        ),
      ),
    );
  }
}
