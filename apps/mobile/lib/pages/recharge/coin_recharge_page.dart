import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../provider/auth_provider.dart';
import '../../provider/service_providers.dart';
import '../../provider/user_provider.dart';

final class CoinRechargePage extends ConsumerStatefulWidget {
  const CoinRechargePage({super.key});

  @override
  ConsumerState<CoinRechargePage> createState() => _CoinRechargePageState();
}

final class _CoinRechargePageState extends ConsumerState<CoinRechargePage> {
  final _amountController = TextEditingController();
  String _selectedPayment = 'wechat';
  bool _isPaying = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _inputAmount {
    final text = _amountController.text;
    final amount = double.tryParse(text);
    return (amount != null && amount > 0) ? amount : 0;
  }

  Future<void> _doRecharge() async {
    final amount = _inputAmount;
    if (amount <= 0) {
      _showToast('请输入充值金额');
      return;
    }

    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn || auth.userId == null) {
      context.pushNamed('login');
      return;
    }

    setState(() => _isPaying = true);

    try {
      final api = ref.read(rechargeApiProvider);
      final result = await api.createRecharge(
        userId: auth.userId!,
        amount: amount,
        paymentMethod: _selectedPayment,
      );

      // 更新本地余额
      final newBalance = (result['new_balance'] as num).toDouble();
      ref.read(userProvider.notifier).updateCoinBalance(newBalance);

      if (mounted) {
        // 跳转到结果页，传递充值金额和赠送金额
        context.pushReplacementNamed(
          'rechargeResult',
          queryParameters: {
            'amount': amount.toString(),
            'bonus': (result['bonus_amount'] as num).toString(),
            'total': (result['total_coins'] as num).toString(),
            'new_balance': newBalance.toString(),
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPaying = false);
        _showToast('充值失败，请重试');
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = ref.watch(userProvider);
    final isLoggedIn = auth.isLoggedIn;
    final canPay = _inputAmount > 0 && !_isPaying;

    return Scaffold(
      appBar: AppBar(
        title: const Text('抖币充值'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.paddingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 当前余额
                  if (isLoggedIn)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimens.paddingLg),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on,
                              size: 28, color: Color(0xFFFFD700)),
                          const SizedBox(width: AppDimens.paddingMd),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '当前余额',
                                style: AppTextStyles.bodyMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${user.coinBalance.toStringAsFixed(0)} 抖币',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppDimens.paddingLg),

                  // 充值金额输入
                  const Text(
                    '充值金额',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppDimens.paddingSm),
                  Container(
                    padding: const EdgeInsets.all(AppDimens.paddingLg),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '¥',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: AppDimens.paddingSm),
                            Expanded(
                              child: TextField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '输入金额',
                                  hintStyle: TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 24,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.paddingMd),
                        // 赠送提示 - 不显示具体金额
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppDimens.paddingSm,
                            horizontal: AppDimens.paddingMd,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusSm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.card_giftcard,
                                size: 16,
                                color: Color(0xFFFFA500),
                              ),
                              const SizedBox(width: AppDimens.paddingSm),
                              Text(
                                '本次充值有额外赠送抖币',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: const Color(0xFFFFA500),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.paddingLg),

                  // 支付方式
                  const Text(
                    '支付方式',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppDimens.paddingSm),
                  _PaymentMethodTile(
                    icon: Icons.wechat,
                    title: '微信支付',
                    subtitle: '推荐使用',
                    isSelected: _selectedPayment == 'wechat',
                    onTap: () => setState(() => _selectedPayment = 'wechat'),
                  ),
                  const SizedBox(height: AppDimens.paddingSm),
                  _PaymentMethodTile(
                    icon: Icons.payments_outlined,
                    title: '支付宝',
                    subtitle: '',
                    isSelected: _selectedPayment == 'alipay',
                    onTap: () => setState(() => _selectedPayment = 'alipay'),
                  ),
                ],
              ),
            ),
          ),

          // 底部确认按钮
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
                  onPressed: canPay ? _doRecharge : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                  ),
                  child: _isPaying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '确认充值 ${_inputAmount > 0 ? '¥${_inputAmount.toStringAsFixed(2)}' : ''}',
                          style: const TextStyle(
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

final class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.05)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppDimens.paddingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall,
                    ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
