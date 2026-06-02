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
  bool _isInitialized = false;

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
    if (_tabController.indexIsChanging) return;
    if (!_isInitialized) return;
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

  void _loadCurrentTab({required WidgetRef ref}) {
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderProvider);

    // 首次 build 时加载当前 tab 的数据（仅在页面重建时执行一次）
    if (!_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _isInitialized = true;
          _loadCurrentTab(ref: ref);
        }
      });
    }

    // 处理外部请求的 tab 切换（支付成功后从 paymentResult 返回）
    final pendingTab = state.pendingTabIndex;
    if (pendingTab != null && pendingTab >= 0 && pendingTab < _tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(orderProvider.notifier).clearPendingTab();
          _tabController.animateTo(pendingTab);
          _loadCurrentTab(ref: ref);
        }
      });
    }

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
                    return _OrderCard(
                      order: state.orders[index],
                      onConfirmSuccess: () {
                        _tabController.animateTo(3);
                        ref.read(orderProvider.notifier).loadOrders(status: 'completed');
                      },
                    );
                  },
                ),
    );
  }
}

final class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order, required this.onConfirmSuccess});

  final OrderModel order;
  final VoidCallback onConfirmSuccess;

  Color get _statusColor {
    return switch (order.status) {
      'pending' => AppColors.warning,
      'paid' => AppColors.primary,
      'shipped' => AppColors.accent,
      'completed' => AppColors.success,
      _ => AppColors.textHint,
    };
  }

  void _confirmOrder(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        title: const Text('确认收货', style: AppTextStyles.titleMedium),
        content: const Text('是否确认已收到所有商品？确认后订单将标记为已完成。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('再想想', style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref.read(orderProvider.notifier).confirmOrder(order.id);
              if (success) {
                onConfirmSuccess();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认收到', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    ...order.items.take(3).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.paddingSm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => context.pushNamed(
                              'productDetail',
                              pathParameters: {'id': item.productId},
                            ),
                            child: ClipRRect(
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
                          ),
                          const SizedBox(width: AppDimens.paddingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => context.pushNamed(
                                    'productDetail',
                                    pathParameters: {'id': item.productId},
                                  ),
                                  child: Text(item.productName,
                                      style: AppTextStyles.bodyLarge,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(height: 2),
                                if (item.spec.isNotEmpty)
                                  Text(
                                    item.spec,
                                    style: AppTextStyles.bodySmall,
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  'x${item.quantity}  ¥${item.productPrice.toStringAsFixed(0)}',
                                  style: AppTextStyles.bodySmall,
                                ),
                                // 已完成订单：已退款商品显示标记，未退款商品显示「退货/退款」按钮
                                if (order.status == 'completed')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: order.isItemRefunded(item.productId)
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.textHint.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              '已退款',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textHint,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          )
                                        : GestureDetector(
                                            onTap: () {
                                              context.pushNamed(
                                                'refundReason',
                                                queryParameters: {
                                                  'order_id': order.id,
                                                  'product_id': item.productId,
                                                  'product_name': item.productName,
                                                  'product_cover': item.productCover,
                                                  'amount': order.payAmount.toString(),
                                                },
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: AppColors.error.withOpacity(0.6)),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '退货/退款',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.error,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                              ],
                            ),
                          ),
                        ],
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
          if (order.status == 'paid') ...[
            const SizedBox(height: AppDimens.paddingSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _confirmOrder(context, ref),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('确认收货', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: AppDimens.paddingSm,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
          if (order.status == 'completed') ...[
            const SizedBox(height: AppDimens.paddingSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.verified,
                  size: 16,
                  color: order.hasAnyRefund ? AppColors.textHint : AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  order.hasAnyRefund ? '部分商品已退款' : '已确认收到',
                  style: TextStyle(
                    fontSize: 13,
                    color: order.hasAnyRefund ? AppColors.textHint : AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!order.hasAnyRefund) const Spacer(),
              ],
            ),
          ],
        ],
      ),
    ),
    );
  }
}
