import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../models/order_model.dart';
import '../../provider/order_provider.dart';
import '../../provider/user_provider.dart';

final class PaymentDetailPage extends ConsumerStatefulWidget {
  const PaymentDetailPage({
    super.key,
    required this.orderId,
    required this.amount,
  });

  final String orderId;
  final double amount;

  @override
  ConsumerState<PaymentDetailPage> createState() => _PaymentDetailPageState();
}

final class _PaymentDetailPageState extends ConsumerState<PaymentDetailPage> {
  int _countdownSeconds = 180;
  bool _isPaying = false;
  OrderModel? _order;
  bool _isLoadingOrder = true;
  String _selectedPayment = 'wechat';

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _loadOrderDetail();
  }

  Future<void> _loadOrderDetail() async {
    try {
      final api = ref.read(orderApiProvider);
      final order = await api.getOrderDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _isLoadingOrder = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOrder = false);
      }
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        }
      });

      if (_countdownSeconds <= 0 && mounted) {
        _onTimeout();
        return false;
      }
      return true;
    });
  }

  void _onTimeout() {
    if (_isPaying) return;
    context.pushReplacementNamed(
      'paymentResult',
      pathParameters: <String, String>{'orderId': widget.orderId},
      queryParameters: <String, String>{
        'status': 'timeout',
        'amount': widget.amount.toString(),
      },
    );
  }

  Future<void> _doPay() async {
    if (_isPaying) return;

    // 如果是抖币支付，先检查余额
    if (_selectedPayment == 'coin') {
      final userState = ref.read(userProvider);
      if (userState.coinBalance < widget.amount) {
        _showInsufficientBalanceDialog();
        return;
      }
    }

    setState(() => _isPaying = true);

    try {
      final success = await ref.read(orderProvider.notifier).payOrder(
        widget.orderId,
        paymentMethod: _selectedPayment,
      );

      if (!mounted) return;

      if (success) {
        context.pushReplacementNamed(
          'paymentResult',
          pathParameters: <String, String>{'orderId': widget.orderId},
          queryParameters: <String, String>{
            'status': 'paid',
            'amount': widget.amount.toString(),
          },
        );
      } else {
        setState(() => _isPaying = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  void _showInsufficientBalanceDialog() {
    final userState = ref.read(userProvider);
    final diff = (widget.amount - userState.coinBalance).toStringAsFixed(0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFFA500), size: 24),
            SizedBox(width: AppDimens.paddingSm),
            Text('余额不足', style: AppTextStyles.titleMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前抖币余额：${userState.coinBalance.toStringAsFixed(0)} 抖币',
              style: AppTextStyles.bodyLarge,
            ),
            const SizedBox(height: AppDimens.paddingSm),
            Text(
              '还需充值约：${diff} 抖币',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimens.paddingMd),
            Container(
              padding: const EdgeInsets.all(AppDimens.paddingSm),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.card_giftcard, size: 16, color: Color(0xFFFFA500)),
                  SizedBox(width: AppDimens.paddingSm),
                  Text(
                    '充值有额外赠送抖币',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFFFA500),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text(
              '取消支付',
              style: TextStyle(color: AppColors.textHint),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pushNamed(
                'coinRecharge',
                queryParameters: <String, String>{
                  'from': 'payment',
                  'order_id': widget.orderId,
                  'amount': widget.amount.toString(),
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
            child: const Text('去充值'),
          ),
        ],
      ),
    );
  }

  String get _formattedTime {
    final minutes = _countdownSeconds ~/ 60;
    final seconds = _countdownSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _countdownSeconds <= 30;
    final userState = ref.watch(userProvider);
    final isCoinSelected = _selectedPayment == 'coin';
    final balanceEnough = userState.coinBalance >= widget.amount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('支付详情'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('order'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: isUrgent ? AppColors.error : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _formattedTime,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: isUrgent ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoadingOrder
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimens.paddingLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Countdown banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppDimens.paddingMd,
                            horizontal: AppDimens.paddingLg,
                          ),
                          decoration: BoxDecoration(
                            color: isUrgent
                                ? AppColors.error.withOpacity(0.1)
                                : AppColors.primary.withOpacity(0.05),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMd),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 18,
                                color: isUrgent
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: AppDimens.paddingSm),
                              Text(
                                isUrgent
                                    ? '即将超时，请尽快支付！'
                                    : '请在 ${_formattedTime} 内完成支付',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isUrgent
                                      ? AppColors.error
                                      : AppColors.textSecondary,
                                  fontWeight:
                                      isUrgent ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimens.paddingLg),

                        // Amount display
                        Center(
                          child: Column(
                            children: [
                              const Text(
                                '实付金额',
                                style: AppTextStyles.bodyMedium,
                              ),
                              const SizedBox(height: AppDimens.paddingSm),
                              Text(
                                '¥${widget.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimens.paddingLg),

                        // Order info
                        Container(
                          padding: const EdgeInsets.all(AppDimens.paddingLg),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMd),
                          ),
                          child: Column(
                            children: [
                              _InfoRow(
                                label: '订单编号',
                                value: widget.orderId,
                              ),
                              const SizedBox(height: AppDimens.paddingSm),
                              _InfoRow(
                                label: '下单时间',
                                value: _order?.createdAt ?? '',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimens.paddingLg),

                        // Product list section
                        const Text(
                          '商品信息',
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: AppDimens.paddingSm),

                        if (_order != null && _order!.items.isNotEmpty)
                          ..._order!.items.map((item) => Container(
                                margin: const EdgeInsets.only(
                                    bottom: AppDimens.paddingSm),
                                padding: const EdgeInsets.all(AppDimens.paddingMd),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(
                                      AppDimens.radiusMd),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          AppDimens.radiusSm),
                                      child: CachedNetworkImage(
                                        imageUrl: item.productCover,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                            color: AppColors.card),
                                        errorWidget: (_, __, ___) => Container(
                                            color: AppColors.card),
                                      ),
                                    ),
                                    const SizedBox(
                                        width: AppDimens.paddingMd),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: AppTextStyles.bodyLarge,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          if (item.spec.isNotEmpty)
                                            Text(
                                              item.spec,
                                              style: AppTextStyles.bodySmall,
                                            ),
                                          const SizedBox(
                                              height: AppDimens.paddingSm),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '¥${item.productPrice.toStringAsFixed(2)}',
                                                style:
                                                    AppTextStyles.priceSmall,
                                              ),
                                              Text(
                                                'x${item.quantity}',
                                                style:
                                                    AppTextStyles.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                        else
                          Container(
                            padding: const EdgeInsets.all(AppDimens.paddingLg),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusMd),
                            ),
                            child: Center(
                              child: Text(
                                '加载商品信息中...',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          ),

                        const SizedBox(height: AppDimens.paddingLg),

                        // Payment method selection
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
                          onTap: () =>
                              setState(() => _selectedPayment = 'wechat'),
                        ),
                        const SizedBox(height: AppDimens.paddingSm),
                        _PaymentMethodTile(
                          icon: Icons.payments_outlined,
                          title: '支付宝',
                          subtitle: '',
                          isSelected: _selectedPayment == 'alipay',
                          onTap: () =>
                              setState(() => _selectedPayment = 'alipay'),
                        ),
                        const SizedBox(height: AppDimens.paddingSm),

                        // 抖币支付
                        _PaymentMethodTile(
                          icon: Icons.monetization_on,
                          title: '抖币支付',
                          subtitle: isCoinSelected
                              ? (balanceEnough
                                  ? '余额充足 ✓'
                                  : '余额不足')
                              : '可用抖币 ${userState.coinBalance.toStringAsFixed(0)}',
                          isSelected: isCoinSelected,
                          trailingColor: isCoinSelected && !balanceEnough
                              ? AppColors.error
                              : null,
                          onTap: () =>
                              setState(() => _selectedPayment = 'coin'),
                          trailing: isCoinSelected && !balanceEnough
                              ? const Icon(Icons.error_outline,
                                  size: 18, color: AppColors.error)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom action bar
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isPaying ? null : _doPay,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppDimens.radiusMd),
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
                                    _selectedPayment == 'coin'
                                        ? '确认支付（抖币 ${widget.amount.toStringAsFixed(0)}）'
                                        : '确认支付',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppDimens.paddingSm),
                        TextButton(
                          onPressed: () => context.goNamed('order'),
                          child: Text(
                            '返回订单列表',
                            style: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium,
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
    this.trailingColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? trailingColor;
  final Widget? trailing;

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
                      style: TextStyle(
                        fontSize: 12,
                        color: trailingColor ?? AppColors.textHint,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (trailing == null)
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
