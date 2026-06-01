import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../provider/order_provider.dart';
import '../../widgets/recommend_products.dart';

final class PaymentResultPage extends ConsumerStatefulWidget {
  const PaymentResultPage({
    super.key,
    required this.orderId,
    required this.status,
    required this.amount,
  });

  final String orderId;
  final String status;
  final double amount;

  @override
  ConsumerState<PaymentResultPage> createState() => _PaymentResultPageState();
}

final class _PaymentResultPageState extends ConsumerState<PaymentResultPage> {
  bool _isPaying = false;
  String? _payStatus;

  @override
  void initState() {
    super.initState();
    _payStatus = widget.status;
    if (widget.status == 'pending') {
      _doPay();
    }
  }

  Future<void> _doPay() async {
    setState(() => _isPaying = true);

    if (!mounted) {
      return;
    }

    final success = await ref.read(orderProvider.notifier).payOrder(widget.orderId);

    if (!mounted) {
      return;
    }

    setState(() {
      _isPaying = false;
      _payStatus = success ? 'paid' : 'failed';
    });

    // Refresh the order list so the order page shows latest status.
    if (success) {
      ref.read(orderProvider.notifier).loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('支付结果')),
      body: _isPaying
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimens.paddingXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: AppDimens.paddingLg),
                    Text('正在支付...', style: AppTextStyles.titleMedium),
                  ],
                ),
              ),
            )
          : _isSuccess()
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimens.paddingXl),
                  child: Column(
                    children: [
                      _buildResult(),
                      const SizedBox(height: AppDimens.paddingXl),
                      const RecommendProducts(),
                    ],
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.paddingXl),
                    child: _buildResult(),
                  ),
                ),
    );
  }

  bool _isSuccess() => _payStatus == 'paid';

  Widget _buildResult() {
    final isSuccess = _payStatus == 'paid';
    final isTimeout = _payStatus == 'timeout';
    final icon = isSuccess ? Icons.check_circle : Icons.error_outline;
    final iconColor = isSuccess ? AppColors.success : AppColors.error;
    final title = isSuccess ? '支付成功' : (isTimeout ? '支付超时' : '支付失败');
    final subtitle = isSuccess
        ? '订单已提交，我们将尽快为您发货'
        : (isTimeout
            ? '支付超时，订单已自动取消，请重新下单'
            : '支付未完成，您可以重新支付');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 72, color: iconColor),
        const SizedBox(height: AppDimens.paddingLg),
        Text(title, style: AppTextStyles.titleLarge),
        const SizedBox(height: AppDimens.paddingSm),
        Text(subtitle, style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppDimens.paddingMd),
        Text(
          '实付金额：¥${widget.amount.toStringAsFixed(2)}',
          style: AppTextStyles.bodyLarge,
        ),
        const SizedBox(height: AppDimens.paddingXs),
        Text(
          '订单号：${widget.orderId}',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppDimens.paddingXl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isSuccess && !isTimeout)
              OutlinedButton(
                onPressed: _doPay,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: AppDimens.paddingMd,
                  ),
                ),
                child: const Text('重新支付'),
              ),
            if (!isSuccess && !isTimeout) const SizedBox(width: AppDimens.paddingLg),
            if (isTimeout)
              OutlinedButton(
                onPressed: () => context.goNamed('cart'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: AppDimens.paddingMd,
                  ),
                ),
                child: const Text('返回购物车'),
              ),
            if (isTimeout) const SizedBox(width: AppDimens.paddingLg),
            ElevatedButton(
              onPressed: () {
                if (isSuccess) {
                  ref.read(orderProvider.notifier).requestSwitchTab(2);
                }
                context.goNamed('order');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: (isSuccess || isTimeout) ? AppColors.primary : AppColors.card,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: AppDimens.paddingMd,
                ),
              ),
              child: const Text('查看订单'),
            ),
          ],
        ),
      ],
    );
  }
}
