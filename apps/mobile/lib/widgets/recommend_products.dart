import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/product_api.dart';
import '../core/app_constants.dart';
import '../models/product_model.dart';
import '../provider/service_providers.dart';

final class RecommendProducts extends ConsumerStatefulWidget {
  const RecommendProducts({super.key, this.title = '猜你喜欢'});

  final String title;

  @override
  ConsumerState<RecommendProducts> createState() => _RecommendProductsState();
}

final class _RecommendProductsState extends ConsumerState<RecommendProducts> {
  List<ProductModel> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ProductApi(client: ref.read(dioClientProvider));
      final products = await api.getRecommend(userId: 'u1');
      if (!mounted) {
        return;
      }
      setState(() {
        _products = products;
        _isLoading = false;
      });
    }
    on Exception {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.paddingLg,
            bottom: AppDimens.paddingSm,
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
              const SizedBox(width: AppDimens.paddingXs),
              Text(widget.title, style: AppTextStyles.titleMedium),
            ],
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.paddingLg,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              return _ProductRecommendCard(
                product: product,
                onTap: () {
                  context.pushNamed(
                    'orderConfirm',
                    queryParameters: <String, String>{
                      'total': product.price.toString(),
                      'count': '1',
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

final class _ProductRecommendCard extends StatelessWidget {
  const _ProductRecommendCard({required this.product, this.onTap});

  final ProductModel product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: AppDimens.paddingSm),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusMd),
              ),
              child: CachedNetworkImage(
                imageUrl: product.coverUrl,
                width: 140,
                height: 120,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.card),
                errorWidget: (_, __, ___) => Container(color: AppColors.card),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimens.paddingSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '¥${product.price.toStringAsFixed(0)}',
                        style: AppTextStyles.priceSmall,
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: AppDimens.paddingXs),
                        Text(
                          '¥${product.originalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textHint,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
