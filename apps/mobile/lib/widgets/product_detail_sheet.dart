import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_constants.dart';
import '../models/coupon_model.dart';
import '../models/product_model.dart';
import '../provider/favorite_provider.dart';
import '../utils/responsive_helper.dart';
import 'coupon_picker_sheet.dart';

final class ProductDetailSheet extends ConsumerStatefulWidget {
  const ProductDetailSheet({
    super.key,
    required this.product,
    this.onAddToCart,
    this.onBuyNow,
    this.onRefreshAi,
    this.onSeekToTime,
    this.onFavorite,
    this.isFavorited = false,
  });

  final ProductModel product;
  final void Function(String spec, int quantity, String? couponId)? onAddToCart;
  final void Function(String spec, int quantity, String? couponId)? onBuyNow;
  final VoidCallback? onRefreshAi;
  final void Function(int seekTime)? onSeekToTime;
  final VoidCallback? onFavorite;
  final bool isFavorited;

  @override
  ConsumerState<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

final class _ProductDetailSheetState extends ConsumerState<ProductDetailSheet> {
  final _scrollController = ScrollController();
  final Map<String, String> _selectedSpecs = {};
  int _quantity = 1;
  bool _showCartAdded = false;

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

  CouponModel? _selectedCoupon;

  /// 获取券后价
  double get _couponPrice {
    if (_selectedCoupon != null) {
      return _selectedCoupon!.getPriceAfterDiscount(widget.product.price);
    }
    return widget.product.price;
  }

  void _onAddToCart(String spec, int quantity) {
    widget.onAddToCart?.call(spec, quantity, _selectedCoupon?.id);
    if (!mounted) return;
    setState(() => _showCartAdded = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showCartAdded = false);
    });
  }

  Future<void> _showCouponPicker() async {
    final result = await showCouponPickerSheet(
      context: context,
      type: CouponType.product,
      productId: widget.product.id,
      productName: widget.product.name,
      productPrice: widget.product.price,
      currentSelected: _selectedCoupon,
    );
    if (result != _selectedCoupon) {
      setState(() => _selectedCoupon = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isSmall = ResponsiveHelper.isSmallScreen(context);

    return DraggableScrollableSheet(
      initialChildSize: isSmall ? 0.6 : 0.75,
      maxChildSize: 0.92,
      minChildSize: isSmall ? 0.45 : 0.5,
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

              // Price and name + coupon entry
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
                        if (_selectedCoupon != null) ...[
                          const SizedBox(width: AppDimens.paddingSm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B6B), Color(0xFFFF4757)],
                              ),
                              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                            ),
                            child: Text(
                              '券后¥${_couponPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        // 优惠券入口按钮
                        GestureDetector(
                          onTap: _showCouponPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.primary, width: 0.5),
                              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_offer,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedCoupon != null
                                      ? '已省¥${_selectedCoupon!.discountAmount.toStringAsFixed(0)}'
                                      : '领券',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.paddingSm),
                    Text(
                      product.name,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppDimens.paddingXs),
                    Row(
                      children: [
                        Text(
                          '已售 ${product.sales}件',
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(width: AppDimens.paddingMd),
                        Text(
                          product.stock > 0 ? '库存 ${product.stock}件' : '已售罄',
                          style: TextStyle(
                            fontSize: 12,
                            color: product.stock > 0 ? AppColors.textSecondary : AppColors.primary,
                          ),
                        ),
                      ],
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

              // Video seek to product highlight / segments
              if (widget.onSeekToTime != null &&
                  (product.segments.isNotEmpty || product.highlightTime > 0))
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.paddingLg,
                  ),
                  child: _SegmentSeekButton(
                    product: product,
                    onSeekToTime: widget.onSeekToTime!,
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

              // Review summary
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.all(AppDimens.paddingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('商品评价', style: AppTextStyles.titleMedium),
                        const Spacer(),
                        const Text('好评率 ', style: AppTextStyles.bodySmall),
                        const Text('98%',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success)),
                        const Icon(Icons.chevron_right,
                            size: 16, color: AppColors.textHint),
                      ],
                    ),
                    const SizedBox(height: AppDimens.paddingMd),
                    _ReviewTile(
                      avatar: '匿',
                      name: '匿名用户',
                      content: '质量非常好，颜色和图片一样，穿上很舒服，物超所值！',
                      rating: 5,
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _ReviewTile(
                      avatar: '小',
                      name: '小王同学',
                      content: '物流很快，包装也很精致，已经是第二次购买了。',
                      rating: 5,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimens.paddingLg),
            ],
          ),
        ),
        // Floating "✓ 已加入购物车" toast
        if (_showCartAdded)
          Positioned(
            left: 0,
            right: 0,
            bottom: 70 + bottomInset,  // just above the action bar
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('已加入购物车',
                        style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        _BottomActionBar(
          onAddToCart: widget.onAddToCart != null
              ? () => _onAddToCart(_selectedSpecs.values.join(','), _quantity)
              : null,
          onBuyNow: (product.stock > 0 && widget.onBuyNow != null)
              ? () => widget.onBuyNow!(
                    _selectedSpecs.values.join(','),
                    _quantity,
                    _selectedCoupon?.id,
                  )
              : null,
          onFavorite: widget.onFavorite,
          // Watch favoriteProvider reactively so the star icon updates
          // immediately when the user toggles it — widget.isFavorited is a
          // one-time snapshot read when the sheet opened.
          isFavorited: ref.watch(favoriteProvider).isFavorited(widget.product.id),
          price: _couponPrice,
          bottomInset: bottomInset,
          stock: product.stock,
          selectedCoupon: _selectedCoupon,
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
}

/// A seek button that adapts to the number of product segments.
///
/// - 0 segments + highlightTime > 0 → single jump button (backward compat)
/// - 1 segment → single jump button with segment label
/// - 2+ segments → button opens a segment picker dialog
final class _SegmentSeekButton extends StatelessWidget {
  const _SegmentSeekButton({required this.product, required this.onSeekToTime});

  final ProductModel product;
  final void Function(int seekTime) onSeekToTime;

  static String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasMultipleSegments = product.segments.length > 1;

    if (hasMultipleSegments) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showSegmentPicker(context),
          icon: const Icon(Icons.playlist_play, size: 18),
          label: Text('${product.segments.length}个讲解片段'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.divider),
            padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingMd),
          ),
        ),
      );
    }

    // Single segment or legacy highlightTime
    final time = product.segments.isNotEmpty
        ? product.segments.first.startTime
        : product.highlightTime;
    final label = product.segments.isNotEmpty
        ? product.segments.first.label
        : null;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => onSeekToTime(time),
        icon: const Icon(Icons.play_circle_outline, size: 18),
        label: Text(
          label != null
              ? '$label (${_formatTime(time)})'
              : '跳转到讲解 (${_formatTime(time)})',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.divider),
          padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingMd),
        ),
      ),
    );
  }

  void _showSegmentPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SegmentPickerSheet(
        segments: product.segments,
        onSelected: (segment) {
          Navigator.of(ctx).pop();
          onSeekToTime(segment.startTime);
        },
      ),
    );
  }
}

/// A bottom sheet listing all product explanation segments.
final class _SegmentPickerSheet extends StatelessWidget {
  const _SegmentPickerSheet({required this.segments, required this.onSelected});

  final List<ProductSegment> segments;
  final void Function(ProductSegment segment) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppDimens.paddingSm),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.paddingMd),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimens.paddingLg),
            child: Text('选择讲解片段', style: AppTextStyles.titleMedium),
          ),
          const SizedBox(height: AppDimens.paddingMd),
          ...segments.map((seg) => ListTile(
                leading: const Icon(Icons.play_circle_outline,
                    color: AppColors.primary),
                title: Text(seg.label, style: AppTextStyles.bodyLarge),
                subtitle: Text(
                  seg.endTime > 0
                      ? '${_SegmentSeekButton._formatTime(seg.startTime)} - ${_SegmentSeekButton._formatTime(seg.endTime)}'
                      : _SegmentSeekButton._formatTime(seg.startTime),
                  style: AppTextStyles.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textHint),
                onTap: () => onSelected(seg),
              )),
          const SizedBox(height: AppDimens.paddingLg),
        ],
      ),
    );
  }
}

/// A single review entry for the review summary section.
final class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.avatar,
    required this.name,
    required this.content,
    this.rating = 5,
  });

  final String avatar;
  final String name;
  final String content;
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.card,
            child: Text(avatar,
                style: const TextStyle(fontSize: 11, color: Colors.white)),
          ),
          const SizedBox(width: AppDimens.paddingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(width: AppDimens.paddingXs),
                    ...List.generate(
                      rating,
                      (_) => const Icon(Icons.star,
                          size: 10, color: AppColors.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(content,
                    style: AppTextStyles.bodyMedium, maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    this.onAddToCart,
    this.onBuyNow,
    this.onFavorite,
    this.isFavorited = false,
    required this.price,
    required this.bottomInset,
    this.stock = 0,
    this.selectedCoupon,
  });

  final VoidCallback? onAddToCart;
  final VoidCallback? onBuyNow;
  final VoidCallback? onFavorite;
  final bool isFavorited;
  final double price;
  final double bottomInset;
  final int stock;
  final CouponModel? selectedCoupon;

  @override
  Widget build(BuildContext context) {
    final soldOut = stock <= 0;

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
          GestureDetector(
            onTap: onFavorite,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.paddingSm),
              child: Icon(
                isFavorited ? Icons.star : Icons.star_border,
                color: isFavorited ? AppColors.primary : AppColors.textSecondary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.paddingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(soldOut ? '已售罄' : '价格',
                    style: TextStyle(
                        fontSize: 11,
                        color: soldOut ? AppColors.error : AppColors.textHint)),
                Text(
                  selectedCoupon != null
                      ? '¥${price.toStringAsFixed(0)}(券后)'
                      : '¥${price.toStringAsFixed(0)}',
                  style: AppTextStyles.price,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.paddingMd),
          if (onAddToCart != null && !soldOut) ...[
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
                child: const Text('加入购物车',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
              ),
            ),
            const SizedBox(width: AppDimens.paddingSm),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: soldOut ? null : onBuyNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: soldOut ? AppColors.card : AppColors.primary,
                foregroundColor: soldOut ? AppColors.textHint : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingMd),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
              child: Text(
                soldOut ? '已售罄' : '立即购买',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: soldOut ? AppColors.textHint : Colors.white,
                ),
              ),
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap != null ? AppColors.textSecondary : AppColors.divider,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: onTap != null ? AppColors.textSecondary : AppColors.divider,
        ),
      ),
    );
  }
}

Future<void> showProductDetailSheet({
  required BuildContext context,
  required ProductModel product,
  required void Function(String spec, int quantity, String? couponId) onAddToCart,
  required void Function(String spec, int quantity, String? couponId) onBuyNow,
  VoidCallback? onRefreshAi,
  void Function(int seekTime)? onSeekToTime,
  VoidCallback? onFavorite,
  bool isFavorited = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProductDetailSheet(
      product: product,
      onAddToCart: (spec, quantity, couponId) => onAddToCart(spec, quantity, couponId),
      onBuyNow: (spec, quantity, couponId) => onBuyNow(spec, quantity, couponId),
      onRefreshAi: onRefreshAi,
      onSeekToTime: onSeekToTime,
      onFavorite: onFavorite,
      isFavorited: isFavorited,
    ),
  );
}
