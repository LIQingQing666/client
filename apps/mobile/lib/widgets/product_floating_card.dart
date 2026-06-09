import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../models/product_model.dart';

/// 视频悬浮商品卡片
final class ProductFloatingCard extends StatefulWidget {
  const ProductFloatingCard({
    super.key,
    required this.product,
    this.onTap,
    this.delay = const Duration(milliseconds: 500),
    this.autoFade = false,
    this.autoFadeDuration = const Duration(seconds: 3),
    this.resetNotifier,
    this.cardWidth,
    this.cardHeight,
    this.layout = ProductCardLayout.vertical,
    this.backgroundColor,
    this.imageFlex = 4,
    this.nameFlex = 1,
    this.priceFlex = 2,
    this.borderRadius,
  });

  /// 商品数据（必传）
  final ProductModel product;

  /// 点击回调
  final VoidCallback? onTap;

  /// 延迟显示时间（默认500ms）
  final Duration delay;

  /// 是否启用自动淡化（横向布局常用）
  final bool autoFade;

  /// 自动淡化间隔（默认3秒）
  final Duration autoFadeDuration;

  /// 外部重置通知器（用于翻页等场景重置显示）
  final ValueNotifier<int>? resetNotifier;

  /// 卡片宽度（null则使用默认值）
  final double? cardWidth;

  /// 卡片高度（null则使用默认值或自动计算）
  final double? cardHeight;

  /// 布局方向
  final ProductCardLayout layout;

  /// 背景颜色（null则使用默认半透明白色）
  final Color? backgroundColor;

  /// 各区域比例（仅纵向布局有效）
  final int imageFlex;
  final int nameFlex;
  final int priceFlex;

  /// 圆角大小（null则使用默认值）
  final double? borderRadius;

  @override
  State<ProductFloatingCard> createState() => _ProductFloatingCardState();
}

/// 卡片布局方向
enum ProductCardLayout {
  /// 纵向布局：图片在上，信息在下
  vertical,

  /// 横向布局：图片在左，信息在右
  horizontal,
}

final class _ProductFloatingCardState extends State<ProductFloatingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _opacityAnimation;

  bool _isVisible = false;
  Timer? _delayTimer;
  Timer? _autoFadeTimer;

  // 默认尺寸
  static const double _defaultVerticalWidth = 88.0;
  static const double _defaultVerticalHeight = 114.0;
  static const double _defaultHorizontalHeight = 64.0;
  static const double _imageSize = 48.0;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // 滑入动画
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutBack,
    ));

    // 透明度动画（支持淡入淡出）
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    ));

    // 延迟显示
    _delayTimer = Timer(widget.delay, () {
      if (mounted) {
        setState(() => _isVisible = true);
        _fadeController.forward();
        if (widget.autoFade) _startAutoFade();
      }
    });

    widget.resetNotifier?.addListener(_onReset);
  }

  @override
  void didUpdateWidget(ProductFloatingCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 商品变化时重置
    if (widget.product.id != oldWidget.product.id) {
      _resetDisplay();
    }

    // 重置通知器变化
    if (widget.resetNotifier != oldWidget.resetNotifier) {
      oldWidget.resetNotifier?.removeListener(_onReset);
      widget.resetNotifier?.addListener(_onReset);
    }
  }

  void _onReset() {
    _resetDisplay();
  }

  void _resetDisplay() {
    _autoFadeTimer?.cancel();
    _fadeController.forward(from: 0);
    if (widget.autoFade) _startAutoFade();
  }

  void _startAutoFade() {
    _autoFadeTimer?.cancel();
    _autoFadeTimer = Timer(widget.autoFadeDuration, () {
      if (mounted) _fadeController.reverse();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _autoFadeTimer?.cancel();
    _fadeController.dispose();
    widget.resetNotifier?.removeListener(_onReset);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: GestureDetector(
          onTap: () {
            if (widget.autoFade) _resetDisplay();
            widget.onTap?.call();
          },
          child: _buildCard(),
        ),
      ),
    );
  }

  /// 构建卡片容器
  Widget _buildCard() {
    final bgColor = widget.backgroundColor ?? Colors.white.withValues(alpha: 0.85);
    final radius = widget.borderRadius ?? AppDimens.radiusMd;

    final cardWidth = widget.cardWidth ??
        (widget.layout == ProductCardLayout.vertical
            ? _defaultVerticalWidth
            : null);
    final cardHeight = widget.cardHeight ??
        (widget.layout == ProductCardLayout.vertical
            ? _defaultVerticalHeight
            : _defaultHorizontalHeight);

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.layout == ProductCardLayout.vertical
          ? _buildVerticalLayout()
          : _buildHorizontalLayout(),
    );
  }

  /// 纵向布局
  Widget _buildVerticalLayout() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: widget.imageFlex,
          child: _buildProductImage(),
        ),
        Expanded(
          flex: widget.nameFlex,
          child: _buildProductName(),
        ),
        Expanded(
          flex: widget.priceFlex,
          child: _buildProductPrice(),
        ),
      ],
    );
  }

  /// 横向布局
  Widget _buildHorizontalLayout() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: widget.product.coverUrl,
              width: _imageSize,
              height: _imageSize,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: _imageSize,
                height: _imageSize,
                color: AppColors.card,
              ),
              errorWidget: (_, __, ___) => Container(
                width: _imageSize,
                height: _imageSize,
                color: AppColors.card,
                child: const Icon(Icons.image, color: AppColors.textHint, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                _buildPriceRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 商品图片
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

  /// 商品名称
  Widget _buildProductName() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      child: Text(
        widget.product.name,
        maxLines: widget.layout == ProductCardLayout.vertical ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: widget.layout == ProductCardLayout.vertical
              ? AppColors.surface
              : Colors.white,
          fontSize: widget.layout == ProductCardLayout.vertical ? 10 : 12,
          fontWeight: FontWeight.w500,
          height: 1.3,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );
  }

  /// 价格区域
  Widget _buildProductPrice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: _buildPriceRow(),
      ),
    );
  }

  /// 价格行组件
  Widget _buildPriceRow() {
    final isHorizontal = widget.layout == ProductCardLayout.horizontal;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '¥',
          style: TextStyle(
            color: isHorizontal ? Colors.white : AppColors.primary,
            fontSize: isHorizontal ? 13 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          widget.product.price.toStringAsFixed(0),
          style: TextStyle(
            color: isHorizontal ? Colors.white : AppColors.primary,
            fontSize: isHorizontal ? 16 : 20,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
        if (widget.product.hasDiscount) ...[
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '¥${widget.product.originalPrice.toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isHorizontal ? Colors.white70 : AppColors.textHint,
                fontSize: isHorizontal ? 9 : 9,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
        if (isHorizontal && widget.product.sales > 0) ...[
          const SizedBox(width: 8),
          Text(
            '已售${widget.product.sales}',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}
