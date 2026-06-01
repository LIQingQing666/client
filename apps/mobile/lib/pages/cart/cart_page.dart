import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../models/cart_model.dart';
import '../../models/coupon_model.dart';
import '../../provider/cart_provider.dart';
import '../../provider/coupon_provider.dart';
import '../../widgets/coupon_picker_sheet.dart';
import '../../widgets/recommend_products.dart';

final class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

final class _CartPageState extends ConsumerState<CartPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cartProvider.notifier).loadCart());
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('购物车'),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(selectedCartItemCouponsProvider.notifier).clearAll();
                notifier.toggleSelectAll();
              },
              child: Text(
                cart.allSelected ? '取消全选' : '全选',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
      body: cart.isLoading && cart.items.isEmpty
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : cart.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: AppDimens.paddingMd),
                      const Text(
                        '购物车是空的',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: AppDimens.paddingLg),
                      ElevatedButton(
                        onPressed: () => GoRouter.of(context).go('/feed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('去逛逛'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        addAutomaticKeepAlives: false,
                        padding: EdgeInsets.symmetric(
                          vertical: AppDimens.paddingSm,
                        ),
                        itemCount: cart.items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == cart.items.length) {
                            return Padding(
                              padding: EdgeInsets.only(top: AppDimens.paddingMd),
                              child: const RecommendProducts(),
                            );
                          }
                          final item = cart.items[index];
                          final itemCoupons = ref.watch(selectedCartItemCouponsProvider);
                          final selectedCoupon = itemCoupons[item.id];

                          return _CartItemTile(
                            item: item,
                            selectedCoupon: selectedCoupon,
                            onToggle: () =>
                                notifier.toggleSelect(item.id),
                            onIncrease: () {
                              if (item.quantity < item.productStock) {
                                notifier.updateQuantity(
                                  item.id,
                                  item.quantity + 1,
                                );
                              }
                            },
                            onDecrease: () {
                              if (item.quantity > 1) {
                                notifier.updateQuantity(
                                  item.id,
                                  item.quantity - 1,
                                );
                              }
                            },
                            onDelete: () {
                              ref.read(selectedCartItemCouponsProvider.notifier).removeCoupon(item.id);
                              notifier.deleteItem(item.id);
                            },
                            onCouponTap: () async {
                              final result = await showCouponPickerSheet(
                                context: context,
                                type: CouponType.product,
                                productId: item.productId,
                                productName: item.productName,
                                productPrice: item.productPrice * item.quantity,
                                currentSelected: selectedCoupon,
                              );
                              ref.read(selectedCartItemCouponsProvider.notifier)
                                  .setCoupon(item.id, result);
                            },
                          );
                        },
                      ),
                    ),
                    _CartBottomBar(
                      cart: cart,
                      onCouponTap: () async {
                        final amountAfterProductCoupons =
                            _calcAmountAfterProductCoupons(cart, ref.read(selectedCartItemCouponsProvider));
                        final result = await showCouponPickerSheet(
                          context: context,
                          type: CouponType.fullReduction,
                          cartTotal: amountAfterProductCoupons,
                          currentSelected:
                              ref.read(selectedFullReductionCouponProvider),
                        );
                        if (result != null || result == null) {
                          ref.read(selectedFullReductionCouponProvider.notifier).state = result;
                        }
                      },
                      onClearCoupon: () {
                        ref.read(selectedFullReductionCouponProvider.notifier).state = null;
                      },
                      onCheckout: () {
                        final selectedCount = cart.selectedCount;
                        if (selectedCount <= 0) return;

                        final itemCoupons = ref.read(selectedCartItemCouponsProvider);
                        final fullReductionCoupon = ref.read(selectedFullReductionCouponProvider);

                        final productCouponDiscount =
                            _calcProductCouponDiscount(cart, itemCoupons);
                        final afterProduct = cart.totalAmount - productCouponDiscount;
                        final fullReductionDiscount =
                            fullReductionCoupon?.discountAmount ?? 0;

                        final usedCouponIds = <String>[];
                        for (final item in cart.selectedItems) {
                          final c = itemCoupons[item.id];
                          if (c != null) usedCouponIds.add(c.id);
                        }
                        if (fullReductionCoupon != null) {
                          usedCouponIds.add(fullReductionCoupon.id);
                        }

                        context.pushNamed(
                          'orderConfirm',
                          queryParameters: <String, String>{
                            'total': cart.totalAmount.toString(),
                            'count': selectedCount.toString(),
                            'product_coupon_discount': productCouponDiscount.toString(),
                            'full_reduction_discount': fullReductionDiscount.toString(),
                            'pay_amount': (afterProduct - fullReductionDiscount).toString(),
                            'coupon_ids': usedCouponIds.join(','),
                          },
                        );
                      },
                    ),
                  ],
                ),
    );
  }

  double _calcAmountAfterProductCoupons(
      CartState cart, Map<String, CouponModel?> itemCoupons) {
    double total = 0;
    for (final item in cart.selectedItems) {
      final coupon = itemCoupons[item.id];
      final itemTotal = item.productPrice * item.quantity;
      if (coupon != null) {
        total += coupon.getPriceAfterDiscount(itemTotal);
      } else {
        total += itemTotal;
      }
    }
    return total;
  }

  double _calcProductCouponDiscount(
      CartState cart, Map<String, CouponModel?> itemCoupons) {
    double discount = 0;
    for (final item in cart.selectedItems) {
      final coupon = itemCoupons[item.id];
      if (coupon != null) {
        final itemTotal = item.productPrice * item.quantity;
        discount += itemTotal - coupon.getPriceAfterDiscount(itemTotal);
      }
    }
    return discount;
  }
}

final class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    this.selectedCoupon,
    required this.onToggle,
    required this.onIncrease,
    required this.onDecrease,
    required this.onDelete,
    required this.onCouponTap,
  });

  final CartItemModel item;
  final CouponModel? selectedCoupon;
  final VoidCallback onToggle;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onDelete;
  final VoidCallback onCouponTap;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingLg,
          vertical: AppDimens.paddingSm,
        ),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDimens.paddingXl),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingLg,
          vertical: AppDimens.paddingSm,
        ),
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: Icon(
                item.selected
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                size: 22,
                color: item.selected ? AppColors.primary : AppColors.textHint,
              ),
            ),
            const SizedBox(width: AppDimens.paddingMd),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              child: CachedNetworkImage(
                imageUrl: item.productCover,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.card),
                errorWidget: (_, __, ___) => Container(color: AppColors.card),
              ),
            ),
            const SizedBox(width: AppDimens.paddingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: AppTextStyles.bodyLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onDelete,
                        child: Padding(
                          padding: const EdgeInsets.only(left: AppDimens.paddingSm),
                          child: Icon(Icons.delete_outline, size: 18, color: AppColors.textHint),
                        ),
                      ),
                    ],
                  ),
                  if (item.spec.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.paddingXs,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        item.spec,
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimens.paddingSm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¥${item.productPrice.toStringAsFixed(0)}',
                            style: AppTextStyles.priceSmall,
                          ),
                          if (item.selected)
                            GestureDetector(
                              onTap: onCouponTap,
                              child: Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedCoupon != null
                                        ? AppColors.primary
                                        : AppColors.textHint.withOpacity(0.5),
                                    width: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_offer,
                                      size: 10,
                                      color: selectedCoupon != null
                                          ? AppColors.primary
                                          : AppColors.textHint,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      selectedCoupon != null
                                          ? '已省¥${selectedCoupon!.discountAmount.toStringAsFixed(0)}'
                                          : '领券',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: selectedCoupon != null
                                            ? AppColors.primary
                                            : AppColors.textHint,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (selectedCoupon != null) ...[
                                      const SizedBox(width: 2),
                                      Text(
                                        '×',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    ],
                                    Icon(
                                      Icons.chevron_right,
                                      size: 10,
                                      color: selectedCoupon != null
                                          ? AppColors.primary
                                          : AppColors.textHint,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          _QtyBtn(
                            icon: Icons.remove,
                            onTap: onDecrease,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.paddingMd,
                            ),
                            child: Text(
                              '${item.quantity}',
                              style: AppTextStyles.bodyLarge,
                            ),
                          ),
                          _QtyBtn(
                            icon: Icons.add,
                            onTap: onIncrease,
                          ),
                        ],
                      ),
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

final class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

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
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, size: 20, color: AppColors.textSecondary),
      ),
    );
  }
}

final class _CartBottomBar extends StatelessWidget {
  const _CartBottomBar({
    required this.cart,
    this.onCouponTap,
    this.onClearCoupon,
    this.onCheckout,
  });

  final CartState cart;
  final VoidCallback? onCouponTap;
  final VoidCallback? onClearCoupon;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final selectedCount = cart.selectedCount;

    return Container(
      padding: EdgeInsets.only(
        left: AppDimens.paddingLg,
        right: AppDimens.paddingLg,
        top: AppDimens.paddingMd,
        bottom: AppDimens.paddingMd + bottomInset,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 满减券选择行
          GestureDetector(
            onTap: onCouponTap,
            child: Row(
              children: [
                Icon(Icons.local_offer_outlined,
                    color: AppColors.primary, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '满减优惠: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final fullReductionCoupon =
                        ref.watch(selectedFullReductionCouponProvider);
                    return GestureDetector(
                      onTap: onCouponTap,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fullReductionCoupon != null
                                ? '${fullReductionCoupon.title}'
                                : '选择满减券',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                          if (fullReductionCoupon != null) ...[
                            const SizedBox(width: 2),
                            GestureDetector(
                              onTap: onClearCoupon,
                              child: Icon(Icons.close,
                                  color: AppColors.textHint, size: 14),
                            ),
                          ],
                          Icon(Icons.chevron_right,
                              color: AppColors.primary, size: 14),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 价格明细
          Consumer(
            builder: (context, ref, _) {
              final itemCoupons = ref.watch(selectedCartItemCouponsProvider);
              final fullReductionCoupon =
                  ref.watch(selectedFullReductionCouponProvider);

              double productDiscount = 0;
              double afterProductTotal = 0;
              for (final item in cart.selectedItems) {
                final itemTotal = item.productPrice * item.quantity;
                final coupon = itemCoupons[item.id];
                if (coupon != null) {
                  final after = coupon.getPriceAfterDiscount(itemTotal);
                  productDiscount += itemTotal - after;
                  afterProductTotal += after;
                } else {
                  afterProductTotal += itemTotal;
                }
              }

              final fullReductionDiscount =
                  fullReductionCoupon?.discountAmount ?? 0;
              final finalAmount = afterProductTotal - fullReductionDiscount;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (productDiscount > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '商品券优惠: ',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                        Text(
                          '-¥${productDiscount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '商品小计',
                            style: TextStyle(
                              fontSize: 11,
                              color: productDiscount > 0
                                  ? AppColors.textHint
                                  : AppColors.textSecondary,
                              decoration: productDiscount > 0
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (productDiscount > 0 || fullReductionDiscount > 0)
                            Text(
                              '券后实付',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '¥${cart.totalAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: productDiscount > 0
                                  ? AppColors.textHint
                                  : AppColors.primary,
                              decoration: productDiscount > 0
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (productDiscount > 0 || fullReductionDiscount > 0)
                            Text(
                              '¥${finalAmount.toStringAsFixed(0)}',
                              style: AppTextStyles.price,
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppDimens.paddingSm),
          ElevatedButton(
            onPressed: selectedCount > 0 ? onCheckout : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.card,
              disabledForegroundColor: AppColors.textHint,
              padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingMd),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              ),
            ),
            child: Text(
              '结算($selectedCount)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
