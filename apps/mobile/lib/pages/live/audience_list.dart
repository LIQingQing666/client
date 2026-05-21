import 'package:flutter/material.dart';

import '../../core/app_constants.dart';

final class Audience {
  const Audience({required this.userId, required this.name, required this.avatar});
  final String userId;
  final String name;
  final String avatar;
}

final class AudienceList extends StatelessWidget {
  const AudienceList({super.key, required this.audiences, required this.onlineCount});

  final List<Audience> audiences;
  final int onlineCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppDimens.paddingSm),
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
          Text('在线观众 ($onlineCount)', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimens.paddingMd),
          Expanded(
            child: audiences.isEmpty
                ? const Center(
                    child: Text('暂无观众信息', style: AppTextStyles.bodyMedium),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingLg),
                    itemCount: audiences.length,
                    itemBuilder: (context, index) {
                      final a = audiences[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.card,
                          child: Text(a.name.isNotEmpty ? a.name[0] : '?', style: AppTextStyles.bodySmall),
                        ),
                        title: Text(a.name, style: AppTextStyles.bodyLarge),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingSm, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                          ),
                          child: const Text('关注', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
