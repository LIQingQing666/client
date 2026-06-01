import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../models/coupon_model.dart';

/// 优惠券卡片组件
///
/// 三种显示样式：
/// - normal: 正常可用
/// - used: 已使用（灰色置灰）
/// - expired: 已过期（灰色置灰）
final class CouponCard extends StatelessWidget {
  const CouponCard({
    super.key,
    required this.coupon,
    this.selected = false,
    this.showAction = false,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.compact = false,
  });

  /// 优惠券数据
  final CouponModel coupon;

  /// 是否选中（用于选择器模式）
  final bool selected;

  /// 是否展示操作按钮
  final bool showAction;

  /// 操作按钮文案
  final String? actionLabel;

  /// 操作按钮回调
  final VoidCallback? onAction;

  /// 卡片点击回调
  final VoidCallback? onTap;

  /// 紧凑模式（用于购物车/商品页嵌入）
  final bool compact;

  String get _formattedDate {
    final f = coupon.validTo;
    return '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';
  }

  Color get _statusColor {
    if (coupon.status == CouponStatus.used ||
        coupon.status == CouponStatus.expired) {
      return AppColors.textHint;
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled =
        coupon.status == CouponStatus.used ||
        coupon.status == CouponStatus.expired;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(
          horizontal: compact ? 0 : AppDimens.paddingLg,
          vertical: AppDimens.paddingSm,
        ),
        padding: EdgeInsets.all(compact ? AppDimens.paddingSm : AppDimens.paddingMd),
        decoration: BoxDecoration(
          color: isDisabled
              ? AppColors.card.withOpacity(0.5)
              : selected
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: selected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : Border.all(
                  color: isDisabled
                      ? AppColors.divider
                      : AppColors.divider.withOpacity(0.3),
                ),
        ),
        child: compact ? _buildCompactRow() : _buildFullCard(isDisabled),
      ),
    );
  }

  /// 紧凑行布局（用于嵌入列表）
  Widget _buildCompactRow() {
    final isDisabled =
        coupon.status == CouponStatus.used ||
        coupon.status == CouponStatus.expired;
    return Row(
      children: [
        // 左侧图标
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: Icon(
            coupon.type == CouponType.product
                ? Icons.local_offer
                : Icons.discount,
            color: _statusColor,
            size: 20,
          ),
        ),
        const SizedBox(width: AppDimens.paddingSm),
        // 标题和描述
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                coupon.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _statusColor,
                ),
              ),
              Text(
                coupon.description,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
        // 金额
        Text(
          '-¥${coupon.discountAmount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _statusColor,
          ),
        ),
        if (selected)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.check_circle, color: AppColors.primary, size: 18),
          ),
        if (showAction && onAction != null) ...[
          const SizedBox(width: AppDimens.paddingSm),
          _ActionButton(
            label: actionLabel ?? '使用',
            onTap: onAction!,
            disabled: isDisabled,
          ),
        ],
      ],
    );
  }

  /// 完整卡片布局（用于优惠券列表页）
  Widget _buildFullCard(bool isDisabled) {
    return Row(
      children: [
        // 左侧金额区域
        Container(
          width: 90,
          padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingMd),
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.15),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppDimens.radiusMd),
              bottomLeft: Radius.circular(AppDimens.radiusMd),
            ),
          ),
          child: Column(
            children: [
              Text(
                '¥${coupon.discountAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _statusColor,
                ),
              ),
              if (coupon.conditionAmount > 0)
                Text(
                  '满${coupon.conditionAmount.toStringAsFixed(0)}可用',
                  style: TextStyle(
                    fontSize: 10,
                    color: _statusColor.withOpacity(0.7),
                  ),
                ),
              if (coupon.conditionAmount == 0)
                const Text(
                  '无门槛',
                  style: TextStyle(fontSize: 10, color: AppColors.textHint),
                ),
            ],
          ),
        ),
        // 中间虚线分隔
        Container(
          width: 1,
          height: 60,
          color: AppColors.divider,
        ),
        // 右侧信息
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.paddingMd,
              vertical: AppDimens.paddingSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  coupon.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDisabled ? AppColors.textHint : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  coupon.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '有效期至 $_formattedDate',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                    const Spacer(),
                    if (coupon.status == CouponStatus.used)
                      const Text(
                        '已使用',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (coupon.status == CouponStatus.expired)
                      const Text(
                        '已过期',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 勾选或操作按钮
        if (selected)
          const Padding(
            padding: EdgeInsets.only(right: AppDimens.paddingMd),
            child: Icon(Icons.check_circle, color: AppColors.primary, size: 24),
          ),
        if (showAction && !selected) ...[
          Padding(
            padding: const EdgeInsets.only(right: AppDimens.paddingSm),
            child: _ActionButton(
              label: actionLabel ?? '使用',
              onTap: onAction!,
              disabled: isDisabled,
            ),
          ),
        ],
      ],
    );
  }
}

final class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingMd,
          vertical: AppDimens.paddingXs,
        ),
        decoration: BoxDecoration(
          color: disabled ? AppColors.divider : AppColors.primary,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: disabled ? AppColors.textHint : Colors.white,
          ),
        ),
      ),
    );
  }
}
