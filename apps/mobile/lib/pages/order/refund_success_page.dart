import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../provider/order_provider.dart';

/// 退货成功「欢迎下次购物」页面
final class RefundSuccessPage extends ConsumerWidget {
  const RefundSuccessPage({
    super.key,
    required this.refundAmount,
    required this.newBalance,
  });

  final double refundAmount;
  final double newBalance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('退款成功'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.paddingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 成功图标
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 56,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: AppDimens.paddingLg),

              // 感谢标题
              const Text(
                '感谢您的支持！',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDimens.paddingSm),
              const Text(
                '欢迎下次购物！',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: AppDimens.paddingXl),

              // 退款金额卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimens.paddingLg),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Column(
                  children: [
                    const Text(
                      '退款金额',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingSm),
                    Text(
                      '${refundAmount.toStringAsFixed(0)} 抖币',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingMd),
                    const Divider(color: AppColors.divider),
                    const SizedBox(height: AppDimens.paddingSm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '当前抖币余额',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${newBalance.toStringAsFixed(0)} 抖币',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimens.paddingXl * 2),

              // 返回按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    // 设置跳转到「已完成」tab
                    ref.read(orderProvider.notifier).requestSwitchTab(3);
                    // 返回订单列表
                    context.goNamed('order');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                  ),
                  child: const Text(
                    '返回订单列表',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.paddingSm),
              TextButton(
                onPressed: () {
                  // 返回首页
                  context.goNamed('feed');
                },
                child: const Text(
                  '继续购物',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
