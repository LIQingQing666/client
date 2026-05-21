import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../models/cart_model.dart';
import '../../models/order_model.dart';
import '../../provider/cart_provider.dart';
import '../../provider/order_provider.dart';

final class OrderConfirmPage extends ConsumerStatefulWidget {
  const OrderConfirmPage({
    super.key,
    required this.total,
    required this.count,
  });

  final double total;
  final int count;

  @override
  ConsumerState<OrderConfirmPage> createState() => _OrderConfirmPageState();
}

final class _OrderConfirmPageState extends ConsumerState<OrderConfirmPage> {
  final _nameController = TextEditingController(text: '张三');
  final _phoneController = TextEditingController(text: '13800000001');
  final _detailController = TextEditingController(text: '北京市朝阳区望京SOHO T1 10层');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final cartState = ref.read(cartProvider);
    final selectedItems = cartState.selectedItems;

    if (selectedItems.isEmpty) {
      _showToast('请选择商品');
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ref.read(orderProvider.notifier).createOrder(
      items: selectedItems,
      address: OrderAddress(
        name: _nameController.text,
        phone: _phoneController.text,
        detail: _detailController.text,
      ),
    );

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    if (result != null) {
      context.pushReplacementNamed(
        'paymentResult',
        pathParameters: <String, String>{'orderId': result.id},
        queryParameters: <String, String>{
          'status': result.status,
          'amount': result.payAmount.toString(),
        },
      );
    }
    else {
      _showToast('创建订单失败，请重试');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final items = cartState.selectedItems;

    return Scaffold(
      appBar: AppBar(title: const Text('确认订单')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.paddingLg),
              children: [
                // Address
                const _SectionTitle(title: '收货地址'),
                const SizedBox(height: AppDimens.paddingSm),
                Container(
                  padding: const EdgeInsets.all(AppDimens.paddingLg),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: Column(
                    children: [
                      _InputField(
                        label: '收货人',
                        controller: _nameController,
                      ),
                      const SizedBox(height: AppDimens.paddingMd),
                      _InputField(
                        label: '手机号',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppDimens.paddingMd),
                      _InputField(
                        label: '详细地址',
                        controller: _detailController,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimens.paddingLg),

                // Items
                const _SectionTitle(title: '商品信息'),
                const SizedBox(height: AppDimens.paddingSm),
                ...items.map((item) => _OrderItemRow(item: item)),

                const SizedBox(height: AppDimens.paddingLg),

                // Price breakdown
                const _SectionTitle(title: '费用明细'),
                const SizedBox(height: AppDimens.paddingSm),
                Container(
                  padding: const EdgeInsets.all(AppDimens.paddingLg),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: Column(
                    children: [
                      _PriceRow(
                        label: '商品总额',
                        value: '¥${widget.total.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: AppDimens.paddingSm),
                      const _PriceRow(
                        label: '优惠',
                        value: '-¥0.00',
                        valueColor: AppColors.success,
                      ),
                      const SizedBox(height: AppDimens.paddingSm),
                      const Divider(color: AppColors.divider),
                      const SizedBox(height: AppDimens.paddingSm),
                      _PriceRow(
                        label: '实付金额',
                        value: '¥${widget.total.toStringAsFixed(2)}',
                        valueStyle: AppTextStyles.price,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Submit
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
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
                      : Text(
                          '提交订单 ¥${widget.total.toStringAsFixed(0)}',
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

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.titleMedium);
  }
}

final class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: AppTextStyles.bodyMedium),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: AppTextStyles.bodyLarge,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

final class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final CartItemModel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.paddingSm),
      padding: const EdgeInsets.all(AppDimens.paddingSm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
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
                Text(
                  item.productName,
                  style: AppTextStyles.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.spec.isNotEmpty)
                  Text(item.spec, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.paddingMd),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${item.productPrice.toStringAsFixed(0)}',
                style: AppTextStyles.priceSmall,
              ),
              Text(
                'x${item.quantity}',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueStyle,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        Text(
          value,
          style: (valueStyle ?? AppTextStyles.bodyLarge).copyWith(
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
