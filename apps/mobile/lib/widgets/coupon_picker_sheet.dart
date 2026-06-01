import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_constants.dart';
import '../models/coupon_model.dart';
import '../provider/coupon_provider.dart';
import 'coupon_card.dart';

/// 底部弹出优惠券选择器
///
/// 两种模式：
/// - product: 商品券选择（商品详情页）
/// - fullReduction: 满减券选择（购物车结算）
Future<CouponModel?> showCouponPickerSheet({
  required BuildContext context,
  required CouponType type,
  String? productId,
  String? productName,
  double? productPrice,
  double? cartTotal,
  CouponModel? currentSelected,
}) {
  return showModalBottomSheet<CouponModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CouponPickerSheet(
      type: type,
      productId: productId,
      productName: productName,
      productPrice: productPrice,
      cartTotal: cartTotal,
      currentSelected: currentSelected,
    ),
  );
}

final class _CouponPickerSheet extends ConsumerStatefulWidget {
  const _CouponPickerSheet({
    required this.type,
    this.productId,
    this.productName,
    this.productPrice,
    this.cartTotal,
    this.currentSelected,
  });

  final CouponType type;
  final String? productId;
  final String? productName;
  final double? productPrice;
  final double? cartTotal;
  final CouponModel? currentSelected;

  @override
  ConsumerState<_CouponPickerSheet> createState() => _CouponPickerSheetState();
}

final class _CouponPickerSheetState extends ConsumerState<_CouponPickerSheet> {
  CouponModel? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentSelected;
  }

  List<CouponModel> _getCoupons() {
    final notifier = ref.read(couponProvider.notifier);
    if (widget.type == CouponType.product) {
      return notifier.getProductCoupons(
        widget.productId ?? '',
        productName: widget.productName,
      );
    }
    return notifier.getFullReductionCoupons();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final coupons = _getCoupons();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽手柄
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
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.paddingLg,
              vertical: AppDimens.paddingMd,
            ),
            child: Row(
              children: [
                Text(
                  widget.type == CouponType.product ? '商品优惠券' : '满减优惠券',
                  style: AppTextStyles.titleMedium,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // 列表
          Flexible(
            child: coupons.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppDimens.paddingXl),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: AppColors.textHint,
                          ),
                          SizedBox(height: AppDimens.paddingMd),
                          Text(
                            '暂无可用优惠券',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
                    itemCount: coupons.length + 1, // +1 for "不使用优惠券"
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildNoneOption();
                      }
                      final coupon = coupons[index - 1];
                      final isEligible = _isCouponEligible(coupon);
                      return Opacity(
                        opacity: isEligible ? 1.0 : 0.4,
                        child: CouponCard(
                          coupon: coupon,
                          selected: _selected?.id == coupon.id,
                          compact: true,
                          onTap: isEligible
                              ? () {
                                  setState(() => _selected = coupon);
                                }
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          // 底部确认按钮
          Container(
            padding: EdgeInsets.fromLTRB(
              AppDimens.paddingLg,
              AppDimens.paddingMd,
              AppDimens.paddingLg,
              AppDimens.paddingMd + bottomInset,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(_selected);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                ),
                child: const Text(
                  '确认',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 判断优惠券是否满足门槛条件
  bool _isCouponEligible(CouponModel coupon) {
    if (coupon.type == CouponType.product && widget.productPrice != null) {
      return coupon.meetsCondition(widget.productPrice!);
    }
    if (coupon.type == CouponType.fullReduction && widget.cartTotal != null) {
      return coupon.meetsCondition(widget.cartTotal!);
    }
    return true;
  }

  /// "不使用优惠券"选项
  Widget _buildNoneOption() {
    return GestureDetector(
      onTap: () => setState(() => _selected = null),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: AppDimens.paddingSm,
        ),
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        decoration: BoxDecoration(
          color: _selected == null
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: _selected == null
              ? Border.all(color: AppColors.primary, width: 1.5)
              : Border.all(color: AppColors.divider.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.block,
              color: AppColors.textHint,
              size: 20,
            ),
            const SizedBox(width: AppDimens.paddingSm),
            const Text(
              '不使用优惠券',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (_selected == null)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
