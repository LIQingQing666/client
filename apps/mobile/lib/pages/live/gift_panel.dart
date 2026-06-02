import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../provider/user_provider.dart';

final class Gift {
  const Gift({required this.id, required this.name, required this.price, required this.icon});
  final String id;
  final String name;
  final int price;
  final String icon;
}

final List<Gift> defaultGifts = const [
  Gift(id: 'g1', name: '❤️', price: 1, icon: '❤️'),
  Gift(id: 'g2', name: '🎁', price: 5, icon: '🎁'),
  Gift(id: 'g3', name: '🚀', price: 10, icon: '🚀'),
  Gift(id: 'g4', name: '🎉', price: 20, icon: '🎉'),
  Gift(id: 'g5', name: '👑', price: 50, icon: '👑'),
  Gift(id: 'g6', name: '🌹', price: 2, icon: '🌹'),
  Gift(id: 'g7', name: '💎', price: 30, icon: '💎'),
  Gift(id: 'g8', name: '🎂', price: 15, icon: '🎂'),
];

final class GiftPanel extends ConsumerWidget {
  const GiftPanel({super.key, required this.onSelect, required this.onClose});

  final void Function(Gift gift) onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final balance = userState.coinBalance;

    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.paddingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('送礼物', style: AppTextStyles.titleMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, size: 14, color: Color(0xFFFFD700)),
                    const SizedBox(width: 4),
                    Text(
                      '余额：${balance.toStringAsFixed(0)} 抖币',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.paddingLg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: AppDimens.paddingMd,
              crossAxisSpacing: AppDimens.paddingMd,
              childAspectRatio: 0.9,
            ),
            itemCount: defaultGifts.length,
            itemBuilder: (context, index) {
              final gift = defaultGifts[index];
              final isAffordable = balance >= gift.price;
              return GestureDetector(
                onTap: () => onSelect(gift),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: !isAffordable
                        ? Border.all(color: AppColors.error.withOpacity(0.3), width: 1)
                        : null,
                  ),
                  child: Opacity(
                    opacity: isAffordable ? 1.0 : 0.5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(gift.icon, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(gift.name, style: AppTextStyles.bodySmall),
                        const SizedBox(height: 2),
                        if (isAffordable)
                          Text('${gift.price}抖币', style: const TextStyle(fontSize: 10, color: AppColors.textHint))
                        else
                          const Text('余额不足', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppDimens.paddingLg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textHint,
                side: const BorderSide(color: AppColors.divider),
              ),
              child: const Text('取消'),
            ),
          ),
        ],
      ),
    );
  }
}
