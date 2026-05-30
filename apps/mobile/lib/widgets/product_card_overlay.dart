import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../models/product_model.dart';
import '../utils/responsive_helper.dart';

final class ProductCardOverlay extends StatelessWidget {
  const ProductCardOverlay({
    super.key,
    required this.product,
    this.onTap,
  });

  final ProductModel product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isSmall = ResponsiveHelper.isSmallScreen(context);
    final imageSize = isSmall ? 48.0 : 64.0;
    final nameStyle = isSmall
        ? AppTextStyles.bodyMedium
        : AppTextStyles.bodyLarge;
    final rightPadding = isSmall ? 56.0 : 72.0;

    return Padding(
      padding: EdgeInsets.only(
        left: isSmall ? AppDimens.paddingSm : AppDimens.paddingLg,
        right: rightPadding,
        bottom: isSmall ? AppDimens.paddingSm : AppDimens.paddingLg,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(
              isSmall ? AppDimens.paddingXs : AppDimens.paddingSm),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                child: CachedNetworkImage(
                  imageUrl: product.coverUrl,
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                      width: imageSize,
                      height: imageSize,
                      color: AppColors.card),
                  errorWidget: (context, url, error) => Container(
                      width: imageSize,
                      height: imageSize,
                      color: AppColors.card),
                ),
              ),
              const SizedBox(width: AppDimens.paddingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: nameStyle,
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
                            style: TextStyle(
                              fontSize: isSmall ? 10 : 11,
                              color: AppColors.textHint,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: AppDimens.paddingXs),
                          Text(
                            product.discountPercent,
                            style: TextStyle(
                              fontSize: isSmall ? 9 : 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '已售${product.sales}',
                      style: isSmall
                          ? const TextStyle(fontSize: 10, color: AppColors.textHint)
                          : AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
                size: AppDimens.iconSm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
