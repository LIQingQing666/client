import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../models/order_model.dart';
import '../../provider/order_provider.dart';

final class OrderPage extends ConsumerStatefulWidget {
  const OrderPage({super.key});

  @override
  ConsumerState<OrderPage> createState() => _OrderPageState();
}

final class _OrderPageState extends ConsumerState<OrderPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<String> _tabs = ['全部', '待支付', '已支付', '已完成'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final statusMap = <int, String?>{
        0: null,
        1: 'pending',
        2: 'paid',
        3: 'completed',
      };
      ref.read(orderProvider.notifier).loadOrders(
            status: statusMap[_tabController.index],
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的订单'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: state.isLoading && state.orders.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : state.orders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                      SizedBox(height: AppDimens.paddingMd),
                      Text('暂无订单', style: AppTextStyles.titleMedium),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppDimens.paddingLg),
                  itemCount: state.orders.length,
                  itemBuilder: (context, index) {
                    return _OrderCard(order: state.orders[index]);
                  },
                ),
    );
  }
}

final class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderModel order;

  Color get _statusColor {
    return switch (order.status) {
      'pending' => AppColors.warning,
      'paid' => AppColors.primary,
      'shipped' => AppColors.accent,
      'completed' => AppColors.success,
      _ => AppColors.textHint,
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(
        'orderDetail',
        pathParameters: {'orderId': order.id},
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimens.paddingMd),
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('订单号：${order.id.substring(0, 8)}...',
                    style: AppTextStyles.bodySmall),
                Text(order.statusText,
                    style: TextStyle(
                      fontSize: 13,
                      color: _statusColor,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
            const Divider(color: AppColors.divider),
            ...order.items.take(3).map((item) => GestureDetector(
                  onTap: () => context.pushNamed(
                    'productDetail',
                    pathParameters: {'id': item.productId},
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.paddingSm),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: item.productCover,
                            width: 56,
                            height: 56,
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
                              Text(item.productName,
                                  style: AppTextStyles.bodyLarge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                'x${item.quantity}  ¥${item.productPrice.toStringAsFixed(0)}',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          if (order.items.length > 3)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.paddingSm),
              child: Text('等${order.items.length}件商品',
                  style: AppTextStyles.bodySmall),
            ),
          const Divider(color: AppColors.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('共${order.items.fold<int>(0, (s, i) => s + i.quantity)}件商品',
                  style: AppTextStyles.bodySmall),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('实付：', style: AppTextStyles.bodySmall),
                  Text('¥${order.payAmount.toStringAsFixed(0)}',
                      style: AppTextStyles.priceSmall),
                ],
              ),
            ],
          ),
          if (order.status == 'pending') ...[
            const SizedBox(height: AppDimens.paddingSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    context.pushNamed(
                      'paymentDetail',
                      pathParameters: <String, String>{'orderId': order.id},
                      queryParameters: <String, String>{
                        'amount': order.payAmount.toString(),
                      },
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: AppDimens.paddingSm,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('去支付', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    );
  }
}
