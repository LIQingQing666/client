import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../models/cart_model.dart';
import '../../provider/cart_provider.dart';
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
    final state = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('购物车'),
        actions: [
          if (state.items.isNotEmpty)
            TextButton(
              onPressed: notifier.toggleSelectAll,
              child: Text(
                state.allSelected ? '取消全选' : '全选',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
      body: state.isLoading && state.items.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : state.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
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
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimens.paddingSm,
                        ),
                        itemCount: state.items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == state.items.length) {
                            return const Padding(
                              padding: EdgeInsets.only(top: AppDimens.paddingMd),
                              child: RecommendProducts(),
                            );
                          }
                          return _CartItemTile(
                            item: state.items[index],
                            onToggle: () =>
                                notifier.toggleSelect(state.items[index].id),
                            onIncrease: () {
                              final item = state.items[index];
                              if (item.quantity < item.productStock) {
                                notifier.updateQuantity(
                                  item.id,
                                  item.quantity + 1,
                                );
                              }
                            },
                            onDecrease: () {
                              final item = state.items[index];
                              if (item.quantity > 1) {
                                notifier.updateQuantity(
                                  item.id,
                                  item.quantity - 1,
                                );
                              }
                            },
                            onDelete: () =>
                                notifier.deleteItem(state.items[index].id),
                          );
                        },
                      ),
                    ),
                    _CartBottomBar(
                      total: state.totalAmount,
                      selectedCount: state.selectedCount,
                      onCheckout: state.selectedCount > 0
                          ? () {
                              context.pushNamed(
                                'orderConfirm',
                                queryParameters: <String, String>{
                                  'total': state.totalAmount.toString(),
                                  'count': state.selectedCount.toString(),
                                },
                              );
                            }
                          : null,
                    ),
                  ],
                ),
    );
  }
}

final class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.onToggle,
    required this.onIncrease,
    required this.onDecrease,
    required this.onDelete,
  });

  final CartItemModel item;
  final VoidCallback onToggle;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onDelete;

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
                        child: const Padding(
                          padding: EdgeInsets.only(left: AppDimens.paddingSm),
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
                      Text(
                        '¥${item.productPrice.toStringAsFixed(0)}',
                        style: AppTextStyles.priceSmall,
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
    required this.total,
    required this.selectedCount,
    this.onCheckout,
  });

  final double total;
  final int selectedCount;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isPriceInvalid = total <= 0 && selectedCount > 0;

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
              Text(isPriceInvalid ? '价格异常' : '合计',
                  style: TextStyle(
                      fontSize: 13,
                      color: isPriceInvalid ? AppColors.error : AppColors.textSecondary)),
              Text(
                isPriceInvalid ? '不可结算' : '¥${total.toStringAsFixed(0)}',
                style: isPriceInvalid
                    ? const TextStyle(fontSize: 14, color: AppColors.error)
                    : AppTextStyles.price,
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: isPriceInvalid ? null : onCheckout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.card,
              disabledForegroundColor: AppColors.textHint,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: AppDimens.paddingMd,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              ),
            ),
            child: Text(
              '结算($selectedCount)',
              style: const TextStyle(
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
