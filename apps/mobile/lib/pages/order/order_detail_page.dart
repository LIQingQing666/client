import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/order_api.dart';
import '../../core/app_constants.dart';
import '../../models/order_model.dart';
import '../../provider/service_providers.dart';

final class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

final class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  OrderModel? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = ref.read(dioClientProvider);
      final api = OrderApi(client: client);
      final order = await api.getOrderDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
        });
      }
    } on Exception {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    return switch (status) {
      'pending' => AppColors.warning,
      'paid' => AppColors.primary,
      'shipped' => AppColors.accent,
      'completed' => AppColors.success,
      _ => AppColors.textHint,
    };
  }

  String _statusText(String status) {
    return switch (status) {
      'pending' => '待支付',
      'paid' => '已支付',
      'shipped' => '已发货',
      'completed' => '已完成',
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('订单详情')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _order == null
              ? const Center(child: Text('订单不存在', style: AppTextStyles.bodyMedium))
              : ListView(
                  padding: const EdgeInsets.all(AppDimens.paddingLg),
                  children: [
                    _StatusCard(
                      status: _order!.status,
                      statusText: _statusText(_order!.status),
                      statusColor: _statusColor(_order!.status),
                    ),
                    const SizedBox(height: AppDimens.paddingMd),
                    _InfoCard(
                      title: '订单信息',
                      children: [
                        _InfoRow(label: '订单编号', value: _order!.id),
                        _InfoRow(
                          label: '下单时间',
                          value: _order!.createdAt.toString().substring(0, 19),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.paddingMd),
                    _InfoCard(
                      title: '商品信息',
                      children: _order!.items.map((item) => GestureDetector(
                        onTap: () => context.pushNamed(
                          'productDetail',
                          pathParameters: {'id': item.productId},
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CachedNetworkImage(
                                  imageUrl: item.productCover,
                                  width: 64,
                                  height: 64,
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
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(
                                      'x${item.quantity}  ¥${item.productPrice.toStringAsFixed(0)}',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.textHint),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: AppDimens.paddingMd),
                    if (_order!.address.detail.isNotEmpty)
                      _InfoCard(
                        title: '收货地址',
                        children: [
                          _InfoRow(
                            label: '收货人',
                            value: _order!.address.name,
                          ),
                          _InfoRow(
                            label: '电话',
                            value: _order!.address.phone,
                          ),
                          _InfoRow(
                            label: '地址',
                            value: _order!.address.detail,
                          ),
                        ],
                      ),
                    const SizedBox(height: AppDimens.paddingMd),
                    _InfoCard(
                      title: '金额信息',
                      children: [
                        _InfoRow(
                          label: '商品总价',
                          value: '¥${_order!.totalAmount.toStringAsFixed(2)}',
                        ),
                        if (_order!.discountAmount > 0)
                          _InfoRow(
                            label: '优惠',
                            value: '-¥${_order!.discountAmount.toStringAsFixed(2)}',
                          ),
                        _InfoRow(
                          label: '实付金额',
                          value: '¥${_order!.payAmount.toStringAsFixed(2)}',
                          valueStyle: AppTextStyles.priceSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.paddingLg),
                    if (_order!.status == 'pending')
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            context.pushNamed(
                              'paymentResult',
                              pathParameters: <String, String>{'orderId': _order!.id},
                              queryParameters: <String, String>{
                                'status': _order!.status,
                                'amount': _order!.payAmount.toString(),
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                            ),
                          ),
                          child: const Text('去支付',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                  ],
                ),
    );
  }
}

final class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.statusText, required this.statusColor});

  final String status;
  final String statusText;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('订单状态', style: AppTextStyles.bodyMedium),
          Text(statusText,
              style: TextStyle(
                fontSize: 15,
                color: statusColor,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

final class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimens.paddingSm),
          ...children,
        ],
      ),
    );
  }
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Flexible(
            child: Text(
              value,
              style: valueStyle ?? AppTextStyles.bodySmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
