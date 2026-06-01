import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../models/product_model.dart';
import '../utils/responsive_helper.dart';

/// A TikTok-style floating product card that overlays the video.
///
/// - In the feed page (horizontal layout): image + info on one row.
/// - In the live room (vertical layout): image on top, info below.
/// - Pass `null` for [product] to hide the card entirely.
final class FloatingProductCard extends StatefulWidget {
  const FloatingProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.resetNotifier,
    this.top,
    this.left,
    this.right,
    this.bottom,
    this.width,
    this.disableAutoFade = false,
    this.verticalLayout = false,
  });

  final ProductModel? product;
  final VoidCallback onTap;
  final ValueNotifier<int>? resetNotifier;

  /// Manual position overrides (null → use feed-page defaults).
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double? width;

  /// When true the card stays at full opacity (no auto-fade).
  final bool disableAutoFade;

  /// When true, use a vertical (image-above-text) layout.  Best for the
  /// live-room card which is tall and narrow.
  final bool verticalLayout;

  @override
  State<FloatingProductCard> createState() => _FloatingProductCardState();
}

final class _FloatingProductCardState extends State<FloatingProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _autoHideTimer;

  static const Duration _visibleDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.value = 1.0;
    if (!widget.disableAutoFade) _resetAutoHide();
    widget.resetNotifier?.addListener(_onReset);
  }

  @override
  void didUpdateWidget(FloatingProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.product?.id != oldWidget.product?.id) {
      if (!widget.disableAutoFade) _resetAutoHide();
    }
    if (widget.resetNotifier != oldWidget.resetNotifier) {
      oldWidget.resetNotifier?.removeListener(_onReset);
      widget.resetNotifier?.addListener(_onReset);
    }
  }

  void _onReset() {
    if (!widget.disableAutoFade) _resetAutoHide();
  }

  void _resetAutoHide() {
    _autoHideTimer?.cancel();
    _fadeController.forward();
    _autoHideTimer = Timer(_visibleDuration, () {
      if (mounted) _fadeController.reverse();
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _fadeController.dispose();
    widget.resetNotifier?.removeListener(_onReset);
    super.dispose();
  }

  // ---- horizontal layout (feed page) ----

  Widget _buildHorizontal(BuildContext context, ProductModel product) {
    final isSmall = ResponsiveHelper.isSmallScreen(context);
    final thumb = isSmall ? 40.0 : 48.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: CachedNetworkImage(
            imageUrl: product.coverUrl,
            width: thumb,
            height: thumb,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(width: thumb, height: thumb, color: AppColors.card),
            errorWidget: (_, __, ___) => Container(
                width: thumb,
                height: thumb,
                color: AppColors.card,
                child: const Icon(Icons.image,
                    color: AppColors.textHint, size: 20)),
          ),
        ),
        const SizedBox(width: AppDimens.paddingSm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(product.name,
                  style: TextStyle(
                      fontSize: isSmall ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('¥${product.price.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: isSmall ? 12 : 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                if (product.hasDiscount) ...[
                  const SizedBox(width: 4),
                  Text('¥${product.originalPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: isSmall ? 9 : 10,
                          color: AppColors.textHint,
                          decoration: TextDecoration.lineThrough)),
                ],
                const SizedBox(width: 6),
                Text('已售${product.sales}',
                    style: TextStyle(
                        fontSize: isSmall ? 9 : 10,
                        color: AppColors.textHint)),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, color: Colors.white.withAlpha(150), size: 18),
      ],
    );
  }

  // ---- vertical layout (live room) ----

  Widget _buildVertical(BuildContext context, ProductModel product) {
    final isSmall = ResponsiveHelper.isSmallScreen(context);
    final priceFont = isSmall ? 13.0 : 15.0;
    final bodyFont = isSmall ? 10.0 : 11.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Product image — fills the top portion
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusMd)),
            child: CachedNetworkImage(
              imageUrl: product.coverUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppColors.card),
              errorWidget: (_, __, ___) => Container(
                  color: AppColors.card,
                  child: const Icon(Icons.image,
                      color: AppColors.textHint, size: 28)),
            ),
          ),
        ),
        // Info section
        Expanded(
          flex: 2,
          child: Padding(
            padding: EdgeInsets.all(isSmall ? AppDimens.paddingXs : AppDimens.paddingSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(product.name,
                    style: TextStyle(
                        fontSize: bodyFont,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const Spacer(),
                // Price
                Text('¥${product.price.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: priceFont,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(height: 1),
                // Stock
                Text(
                    product.stock > 0 ? '库存 ${product.stock}' : '已售罄',
                    style: TextStyle(
                        fontSize: bodyFont - 2,
                        color: product.stock > 0
                            ? AppColors.textHint
                            : AppColors.error)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    if (product == null) return const SizedBox.shrink();

    final hasManualPos = widget.top != null ||
        widget.left != null ||
        widget.right != null ||
        widget.bottom != null;

    final isSmall = ResponsiveHelper.isSmallScreen(context);
    final pad = isSmall ? AppDimens.paddingXs : AppDimens.paddingSm;

    final card = FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () {
          if (!widget.disableAutoFade) _resetAutoHide();
          widget.onTap();
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(185),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(color: Colors.white.withAlpha(25), width: 0.5),
          ),
          child: widget.verticalLayout
              ? _buildVertical(context, product)
              : Padding(
                  padding: EdgeInsets.all(pad),
                  child: _buildHorizontal(context, product),
                ),
        ),
      ),
    );

    if (hasManualPos) return card;

    // Default feed-page positioning
    return Positioned(
      left: isSmall ? AppDimens.paddingSm : AppDimens.paddingLg,
      right: 68,
      bottom: 210,
      child: card,
    );
  }
}
