import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';

final class RechargeResultPage extends StatelessWidget {
  const RechargeResultPage({
    super.key,
    required this.amount,
    required this.bonus,
    required this.total,
    required this.newBalance,
  });

  final double amount;
  final double bonus;
  final double total;
  final double newBalance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('充值结果'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.paddingXl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 成功图标
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingLg),
                    const Text(
                      '充值成功',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingXl),

                    // 充值详情卡片
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimens.paddingLg),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      child: Column(
                        children: [
                          // 到账总额
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '+${total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                              const SizedBox(width: AppDimens.paddingSm),
                              const Text(
                                '抖币',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.paddingMd),
                          const Divider(color: AppColors.divider),
                          const SizedBox(height: AppDimens.paddingMd),

                          // 充值金额
                          _DetailRow(
                            icon: Icons.payments_outlined,
                            label: '充值',
                            value: '${amount.toStringAsFixed(2)} 元',
                          ),
                          const SizedBox(height: AppDimens.paddingSm),
                          // 额外赠送
                          _DetailRow(
                            icon: Icons.card_giftcard,
                            label: '额外赠送',
                            value: '+${bonus.toStringAsFixed(1)} 抖币',
                            valueColor: const Color(0xFFFFA500),
                          ),
                          const SizedBox(height: AppDimens.paddingMd),
                          const Divider(color: AppColors.divider),
                          const SizedBox(height: AppDimens.paddingMd),
                          // 当前余额
                          _DetailRow(
                            icon: Icons.account_balance_wallet_outlined,
                            label: '当前余额',
                            value: '${newBalance.toStringAsFixed(0)} 抖币',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDimens.paddingXl),

                    // 提示
                    Text(
                      '${bonus.toStringAsFixed(1)} 抖币为本次额外赠送福利 🎉',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 底部按钮
          Container(
            padding: EdgeInsets.fromLTRB(
              AppDimens.paddingLg,
              AppDimens.paddingMd,
              AppDimens.paddingLg,
              AppDimens.paddingMd + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    // 跳转到个人中心
                    context.go('/mine');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                  ),
                  child: const Text(
                    '返回个人中心',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: AppDimens.paddingSm),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
