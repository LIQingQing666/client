import 'package:flutter/material.dart';

import '../../core/app_constants.dart';

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

final class GiftPanel extends StatelessWidget {
  const GiftPanel({super.key, required this.onSelect});

  final void Function(Gift gift) onSelect;

  @override
  Widget build(BuildContext context) {
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
          const Text('送礼物', style: AppTextStyles.titleMedium),
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
              return GestureDetector(
                onTap: () {
                  onSelect(gift);
                  Navigator.of(context).pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(gift.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(gift.name, style: AppTextStyles.bodySmall),
                      Text('${gift.price}积分', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppDimens.paddingLg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
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
