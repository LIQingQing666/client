import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../provider/auth_provider.dart';
import '../../provider/user_provider.dart';

final class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = ref.watch(userProvider);
    final isLoggedIn = auth.isLoggedIn;
    final userId = auth.userId ?? '';
    final role = auth.role;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(
          top: AppDimens.paddingXl * 2,
          bottom: AppDimens.paddingXl,
        ),
        children: [
          _buildUserHeader(
            context,
            isLoggedIn: isLoggedIn,
            userId: userId,
            nickname: user.nickname,
            avatar: user.avatar,
          ),
          const SizedBox(height: AppDimens.paddingXl),
          _buildMenuSection(context, isLoggedIn: isLoggedIn, role: role),
        ],
      ),
    );
  }

  Widget _buildUserHeader(
    BuildContext context, {
    required bool isLoggedIn,
    required String userId,
    String? nickname,
    String? avatar,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (isLoggedIn) {
              context.pushNamed('editProfile');
            } else {
              context.pushNamed('login');
            }
          },
          child: CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.card,
            backgroundImage: avatar != null && avatar.isNotEmpty
                ? (avatar.startsWith('/') ? FileImage(File(avatar)) : NetworkImage(avatar))
                : null,
            child: avatar == null || avatar.isEmpty
                ? Icon(
                    Icons.person,
                    size: 40,
                    color: isLoggedIn ? AppColors.primary : AppColors.textHint,
                  )
                : null,
          ),
        ),
        const SizedBox(height: AppDimens.paddingMd),
        GestureDetector(
          onTap: () {
            if (!isLoggedIn) {
              context.pushNamed('login');
            }
          },
          child: Text(
            isLoggedIn
                ? (nickname != null && nickname.isNotEmpty ? nickname : '用户 $userId')
                : '点击登录',
            style: AppTextStyles.titleMedium,
          ),
        ),
        const SizedBox(height: AppDimens.paddingXs),
        Text(
          isLoggedIn ? 'ID: $userId' : '登录后享受更多功能',
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context, {required bool isLoggedIn, required String? role}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.paddingLg),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            if (isLoggedIn) ...[
              _buildMenuItem(
                context,
                icon: Icons.favorite_outline,
                title: '我的关注',
                subtitle: '查看关注的主播和用户',
                onTap: () => context.pushNamed('following'),
              ),
              _buildDivider(),
              _buildMenuItem(
                context,
                icon: Icons.bookmark_outline,
                title: '我的收藏',
                subtitle: '收藏的视频和商品',
                onTap: () => context.pushNamed('favorites'),
              ),
              _buildDivider(),
              _buildMenuItem(
                context,
                icon: Icons.mail_outline,
                title: '消息',
                subtitle: '查看系统通知和互动消息',
                onTap: () => context.pushNamed('messages'),
              ),
              _buildDivider(),
              _buildMenuItem(
                context,
                icon: Icons.receipt_long_outlined,
                title: '我的订单',
                subtitle: '查看全部订单',
                onTap: () => context.go('/order'),
              ),
              _buildDivider(),
              _buildMenuItem(
                context,
                icon: Icons.shopping_cart_outlined,
                title: '购物车',
                subtitle: '查看购物车商品',
                onTap: () => context.go('/cart'),
              ),
              _buildDivider(),
              if (role == 'merchant')
                _buildMenuItem(
                  context,
                  icon: Icons.store_outlined,
                  title: '商家后台',
                  subtitle: '商品和视频管理',
                  onTap: () => context.push('/admin'),
                ),
              if (role == 'merchant') _buildDivider(),
            ],
            _buildMenuItem(
              context,
              icon: Icons.settings_outlined,
              title: '设置',
              subtitle: '账号与偏好设置',
              onTap: () => context.pushNamed('settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(title, style: AppTextStyles.bodyLarge),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      color: AppColors.divider,
      height: 1,
      indent: AppDimens.paddingXl * 2 + AppDimens.paddingMd,
    );
  }
}
