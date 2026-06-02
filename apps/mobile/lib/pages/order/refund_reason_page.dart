import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../provider/order_provider.dart';
import '../../provider/user_provider.dart';

/// 退货退款原因选择页面
final class RefundReasonPage extends ConsumerStatefulWidget {
  const RefundReasonPage({
    super.key,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.productCover,
    required this.amount,
  });

  final String orderId;
  final String productId;
  final String productName;
  final String productCover;
  final double amount;

  @override
  ConsumerState<RefundReasonPage> createState() => _RefundReasonPageState();
}

final class _RefundReasonPageState extends ConsumerState<RefundReasonPage> {
  final List<_RefundReason> _reasons = [
    _RefundReason('买错了', '买错规格/颜色/版本'),
    _RefundReason('买多了', '数量太多不需要了'),
    _RefundReason('尺寸不合适', '尺码不匹配'),
    _RefundReason('单纯不想要了', '改变主意'),
    _RefundReason('商品有瑕疵', '收到商品有质量问题'),
    _RefundReason('其他原因', '其他'),
  ];

  int? _selectedIndex;
  bool _isSubmitting = false;

  Future<void> _submitRefund() async {
    if (_selectedIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择退款原因')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final reason = _reasons[_selectedIndex!].reason;

    final result = await ref.read(orderProvider.notifier).refundOrder(
      orderId: widget.orderId,
      productId: widget.productId,
      reason: reason,
    );

    if (!mounted) return;

    if (result != null) {
      // 更新本地抖币余额
      final newBalance = (result['new_balance'] as num?)?.toDouble() ?? 0;
      ref.read(userProvider.notifier).updateCoinBalance(newBalance);

      final refundAmount = (result['refund_amount'] as num?)?.toDouble() ?? 0;

      // 导航到成功页
      context.pushReplacementNamed(
        'refundSuccess',
        queryParameters: {
          'refund_amount': refundAmount.toString(),
          'new_balance': newBalance.toString(),
        },
      );
    } else {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('退货退款'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.paddingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 商品信息卡片
                  Container(
                    padding: const EdgeInsets.all(AppDimens.paddingMd),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                          child: CachedNetworkImage(
                            imageUrl: widget.productCover,
                            width: 72,
                            height: 72,
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
                              Text(
                                widget.productName,
                                style: AppTextStyles.bodyLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppDimens.paddingSm),
                              Text(
                                '实付金额：${widget.amount.toStringAsFixed(2)} 抖币',
                                style: AppTextStyles.priceSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.paddingLg),

                  // 退款原因标题
                  const Text(
                    '退款原因',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppDimens.paddingSm),
                  const Text(
                    '请选择退款原因（必选）',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: AppDimens.paddingMd),

                  // 原因选项列表
                  ...List.generate(_reasons.length, (index) {
                    final isSelected = _selectedIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppDimens.paddingSm),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _reasons[index].title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _reasons[index].subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textHint,
                                    ),
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
                  }),
                ],
              ),
            ),
          ),

          // 底部提交按钮
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
                  onPressed: _isSubmitting ? null : _submitRefund,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    disabledForegroundColor: Colors.white.withOpacity(0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '提交退款申请',
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

final class _RefundReason {
  const _RefundReason(this.title, this.subtitle);

  final String title;
  final String subtitle;

  String get reason => title;
}
