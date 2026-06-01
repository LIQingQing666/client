import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../models/coupon_model.dart';
import '../../provider/coupon_provider.dart';
import '../../widgets/coupon_card.dart';

/// 我的优惠券页面
///
/// 展示用户拥有的所有优惠券，支持按状态筛选：
/// - 未使用
/// - 已使用
/// - 已过期
final class CouponListPage extends ConsumerStatefulWidget {
  const CouponListPage({super.key});

  @override
  ConsumerState<CouponListPage> createState() => _CouponListPageState();
}

final class _CouponListPageState extends ConsumerState<CouponListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 进入页面时刷新过期状态
    Future.microtask(
      () => ref.read(couponProvider.notifier).refreshExpiredStatus(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的优惠券'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          tabs: const [
            Tab(text: '未使用'),
            Tab(text: '已使用'),
            Tab(text: '已过期'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CouponTab(status: CouponStatus.unused),
          _CouponTab(status: CouponStatus.used),
          _CouponTab(status: CouponStatus.expired),
        ],
      ),
    );
  }
}

final class _CouponTab extends ConsumerWidget {
  const _CouponTab({required this.status});

  final CouponStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(couponProvider.notifier);
    final List<CouponModel> coupons;

    switch (status) {
      case CouponStatus.unused:
        coupons = notifier.getUnusedCoupons();
        break;
      case CouponStatus.used:
        coupons = notifier.getUsedCoupons();
        break;
      case CouponStatus.expired:
        coupons = notifier.getExpiredCoupons();
        break;
    }

    if (coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == CouponStatus.unused
                  ? Icons.inventory_2_outlined
                  : status == CouponStatus.used
                      ? Icons.check_circle_outline
                      : Icons.timer_off_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: AppDimens.paddingMd),
            Text(
              status == CouponStatus.unused
                  ? '暂无可用优惠券'
                  : status == CouponStatus.used
                      ? '暂无已使用优惠券'
                      : '暂无已过期优惠券',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
      itemCount: coupons.length,
      itemBuilder: (context, index) {
        final coupon = coupons[index];
        return CouponCard(
          coupon: coupon,
          showAction: status == CouponStatus.unused,
          actionLabel: '立即使用',
          onAction: () {
            // 跳转到对应商品页或购物车
            _handleUseCoupon(context, coupon);
          },
        );
      },
    );
  }

  void _handleUseCoupon(BuildContext context, CouponModel coupon) {
    if (coupon.type == CouponType.product && coupon.productId != null) {
      // 商品券：跳转到商品详情页
      GoRouter.of(context).pushNamed(
        'productDetail',
        pathParameters: <String, String>{'id': coupon.productId!},
      );
    } else {
      // 满减券：跳转到购物车
      GoRouter.of(context).go('/cart');
    }
  }
}
