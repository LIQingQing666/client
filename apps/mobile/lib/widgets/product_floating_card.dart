import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../models/product_model.dart';

/// 视频右侧悬浮商品卡片
/// 尺寸约为商品按钮的两倍大，白色半透明底色
/// 布局：商品图片(4) : 商品名称(1) : 价格(2) 从上到下
final class ProductFloatingCard extends StatefulWidget {
  const ProductFloatingCard({
    super.key,
    required this.product,
    this.delay = const Duration(milliseconds: 500),
    this.onTap,
  });

  final ProductModel product;
  final Duration delay;
  final VoidCallback? onTap;

  @override
  State<ProductFloatingCard> createState() => _ProductFloatingCardState();
}

final class _ProductFloatingCardState extends State<ProductFloatingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isVisible = false;
  Timer? _delayTimer;

  // 商品按钮尺寸（参考 VideoPlayerWidget 中的 _ActionButton）
  static const double _productButtonSize = 44.0;

  // 卡片尺寸 = 商品按钮的 2 倍宽，高度按比例
  static const double _cardWidth = _productButtonSize * 2;  // 88
  static const double _cardHeight = _cardWidth * 1.3;       // 约114

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // 从右侧滑入
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );

    _delayTimer = Timer(widget.delay, () {
      if (mounted) {
        setState(() => _isVisible = true);
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: _cardWidth,
            height: _cardHeight,
            decoration: BoxDecoration(
              // 白色半透明底色
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              // 轻微阴影增加层次感
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 商品图片区域 - 占 4/7
                Expanded(
                  flex: 4,
                  child: _buildProductImage(),
                ),
                // 商品名称区域 - 占 1/7（固定2行）
                Expanded(
                  flex: 1,
                  child: _buildProductName(),
                ),
                // 价格区域 - 占 2/7
                Expanded(
                  flex: 2,
                  child: _buildProductPrice(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建商品图片
  Widget _buildProductImage() {
    return CachedNetworkImage(
      imageUrl: widget.product.coverUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        color: AppColors.card,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.textHint,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppColors.card,
        child: const Icon(
          Icons.shopping_bag_outlined,
          color: AppColors.textHint,
          size: 20,
        ),
      ),
    );
  }

  /// 构建商品名称（固定2行，不管是否完全显示）
  Widget _buildProductName() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      child: Text(
        widget.product.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.surface,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.3,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );
  }

  /// 构建价格（放大显示）
  Widget _buildProductPrice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // 价格符号
            const Text(
              '¥',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            // 价格数字（放大）
            Text(
              widget.product.price.toStringAsFixed(0),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            // 原价
            if (widget.product.hasDiscount) ...[
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  '¥${widget.product.originalPrice.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 9,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
