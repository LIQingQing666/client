import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../models/product_model.dart';

final class ProductDetailSheet extends StatefulWidget {
  const ProductDetailSheet({
    super.key,
    required this.product,
    this.onAddToCart,
    this.onBuyNow,
    this.onRefreshAi,
    this.onSeekToTime,
  });

  final ProductModel product;
  final VoidCallback? onAddToCart;
  final VoidCallback? onBuyNow;
  final VoidCallback? onRefreshAi;
  final VoidCallback? onSeekToTime;

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

final class _ProductDetailSheetState extends State<ProductDetailSheet> {
  final _scrollController = ScrollController();
  final Map<String, String> _selectedSpecs = {};
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    for (final spec in widget.product.specs) {
      if (spec.values.isNotEmpty) {
        _selectedSpecs[spec.name] = spec.values.first;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusXl),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Product image carousel
              SizedBox(
                height: 280,
                child: PageView.builder(
                  itemCount: product.images.isNotEmpty ? product.images.length : 1,
                  itemBuilder: (context, index) {
                    final url = product.images.isNotEmpty
                        ? product.images[index]
                        : product.coverUrl;
                    return CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      height: 280,
                      placeholder: (context, url) =>
                          Container(height: 280, color: AppColors.card),
                      errorWidget: (context, url, error) =>
                          Container(height: 280, color: AppColors.card),
                    );
                  },
                ),
              ),

              // Price and name
              Padding(
                padding: const EdgeInsets.all(AppDimens.paddingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥${product.price.toStringAsFixed(0)}',
                          style: AppTextStyles.price,
                        ),
                        if (product.hasDiscount) ...[
                          const SizedBox(width: AppDimens.paddingSm),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '¥${product.originalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textHint,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimens.paddingSm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.paddingXs,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                            ),
                            child: Text(
                              product.discountPercent,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppDimens.paddingSm),
                    Text(
                      product.name,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppDimens.paddingXs),
                    Text(
                      '已售 ${product.sales}件',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Specs
              ...product.specs.map((spec) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.paddingLg,
                    vertical: AppDimens.paddingMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(spec.name, style: AppTextStyles.bodyMedium),
                      const SizedBox(height: AppDimens.paddingSm),
                      Wrap(
                        spacing: AppDimens.paddingSm,
                        runSpacing: AppDimens.paddingSm,
                        children: spec.values.map((value) {
                          final isSelected = _selectedSpecs[spec.name] == value;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSpecs[spec.name] = value;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.paddingMd,
                                vertical: AppDimens.paddingSm,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.surface
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                                border: isSelected
                                    ? null
                                    : Border.all(color: AppColors.divider),
                              ),
                              child: Text(
                                value,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),

              const Divider(height: 1),

              // Quantity
              Padding(
                padding: const EdgeInsets.all(AppDimens.paddingLg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('数量', style: AppTextStyles.bodyMedium),
                    Row(
                      children: [
                        _QtyButton(
                          icon: Icons.remove,
                          onTap: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        const SizedBox(width: AppDimens.paddingMd),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '$_quantity',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyLarge,
                          ),
                        ),
                        const SizedBox(width: AppDimens.paddingMd),
                        _QtyButton(
                          icon: Icons.add,
                          onTap: _quantity < product.stock
                              ? () => setState(() => _quantity++)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // AI Sales Point
              if (product.aiSalesPoint.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppDimens.paddingLg),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimens.paddingMd),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_awesome,
                                color: AppColors.accent, size: 16),
                            const SizedBox(width: AppDimens.paddingSm),
                            Expanded(
                              child: Text(
                                product.aiSalesPoint,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.onRefreshAi != null) ...[
                          const SizedBox(height: AppDimens.paddingSm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: widget.onRefreshAi,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh,
                                      color: AppColors.accent, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'AI 重新生成',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Video seek to product highlight
              if (product.highlightTime > 0 && widget.onSeekToTime != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.paddingLg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onSeekToTime,
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: Text(
                        '跳转到讲解 (${_formatTime(product.highlightTime)})',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimens.paddingMd,
                        ),
                      ),
                    ),
                  ),
                ),

              // Description
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.paddingLg,
                  0,
                  AppDimens.paddingLg,
                  AppDimens.paddingLg,
                ),
                child: Text(
                  product.description,
                  style: AppTextStyles.bodyMedium,
                ),
              ),

              const SizedBox(height: AppDimens.paddingLg),
            ],
          ),
        ),
        _BottomActionBar(
          onAddToCart: widget.onAddToCart,
          onBuyNow: widget.onBuyNow,
          price: product.price,
          bottomInset: bottomInset,
        ),
      ],
    ),
  );
},
    );
  }

  // Exposed methods
  Map<String, String> get selectedSpecs => Map.unmodifiable(_selectedSpecs);
  int get quantity => _quantity;

  static String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

final class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    this.onAddToCart,
    this.onBuyNow,
    required this.price,
    required this.bottomInset,
  });

  final VoidCallback? onAddToCart;
  final VoidCallback? onBuyNow;
  final double price;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppDimens.paddingLg,
        right: AppDimens.paddingLg,
        top: AppDimens.paddingMd,
        bottom: AppDimens.paddingMd + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('价格', style: AppTextStyles.bodySmall),
              Text(
                '¥${price.toStringAsFixed(0)}',
                style: AppTextStyles.price,
              ),
            ],
          ),
          const SizedBox(width: AppDimens.paddingMd),
          if (onAddToCart != null) ...[
            Expanded(
              child: ElevatedButton(
                onPressed: onAddToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingMd),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                ),
                child: const Text('加入购物车', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
              ),
            ),
            const SizedBox(width: AppDimens.paddingSm),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: onBuyNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingMd),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
              child: const Text('立即购买', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

final class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap != null ? AppColors.textSecondary : AppColors.divider,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? AppColors.textSecondary : AppColors.divider,
        ),
      ),
    );
  }
}

Future<void> showProductDetailSheet({
  required BuildContext context,
  required ProductModel product,
  required VoidCallback onAddToCart,
  required VoidCallback onBuyNow,
  VoidCallback? onRefreshAi,
  VoidCallback? onSeekToTime,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProductDetailSheet(
      product: product,
      onAddToCart: onAddToCart,
      onBuyNow: onBuyNow,
      onRefreshAi: onRefreshAi,
      onSeekToTime: onSeekToTime,
    ),
  );
}
