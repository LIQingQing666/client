import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/coupon_model.dart';

/// 当前选中的商品券（商品详情页使用）
final selectedProductCouponProvider =
    StateProvider<CouponModel?>((ref) => null);

/// 当前选中的满减券（购物车结算使用）
final selectedFullReductionCouponProvider =
    StateProvider<CouponModel?>((ref) => null);

/// 购物车中每个商品单独选中的商品券（key = cartItem.id）
final selectedCartItemCouponsProvider =
    StateNotifierProvider<SelectedCartItemCouponsNotifier, Map<String, CouponModel?>>(
  (ref) => SelectedCartItemCouponsNotifier(),
);

final class SelectedCartItemCouponsNotifier extends StateNotifier<Map<String, CouponModel?>> {
  SelectedCartItemCouponsNotifier() : super({});

  /// 设置某个购物车项的商品券
  void setCoupon(String cartItemId, CouponModel? coupon) {
    state = Map.from(state)..[cartItemId] = coupon;
  }

  /// 清除某个购物车项的商品券
  void removeCoupon(String cartItemId) {
    state = Map.from(state)..remove(cartItemId);
  }

  /// 清除所有商品券
  void clearAll() {
    state = {};
  }
}

/// 优惠券状态管理
final class CouponNotifier extends StateNotifier<List<CouponModel>> {
  CouponNotifier() : super(_mockCoupons);

  /// ==================== Mock 数据 ====================
  /// TODO: 替换为真实 API 调用
  static final List<CouponModel> _mockCoupons = [
    // ----- 商品券（鸡胸肉） -----
    CouponModel(
      id: 'cpn_chicken_new',
      userId: 'u1',
      type: CouponType.product,
      title: '减脂专享券',
      description: '鸡胸肉立减¥10',
      conditionAmount: 0,
      discountAmount: 10,
      productName: '鸡胸肉',
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
      status: CouponStatus.unused,
    ),
    CouponModel(
      id: 'cpn_chicken_bulk',
      userId: 'u1',
      type: CouponType.product,
      title: '囤货特惠券',
      description: '满100减25',
      conditionAmount: 100,
      discountAmount: 25,
      productName: '鸡胸肉',
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
      status: CouponStatus.unused,
    ),

    // ----- 商品券（关联商品 p1） -----
    CouponModel(
      id: 'cpn_p1_new_user',
      userId: 'u1',
      type: CouponType.product,
      title: '新人专享',
      description: '满100减20',
      conditionAmount: 100,
      discountAmount: 20,
      productId: 'p1',
      productName: '商品A',
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
      status: CouponStatus.unused,
    ),
    CouponModel(
      id: 'cpn_p1_flash',
      userId: 'u1',
      type: CouponType.product,
      title: '爆品券',
      description: '立减¥10',
      conditionAmount: 0,
      discountAmount: 10,
      productId: 'p1',
      productName: '商品A',
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
      status: CouponStatus.unused,
    ),
    CouponModel(
      id: 'cpn_p1_vip',
      userId: 'u1',
      type: CouponType.product,
      title: '会员专享',
      description: '满200减50',
      conditionAmount: 200,
      discountAmount: 50,
      productId: 'p1',
      productName: '商品A',
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
      status: CouponStatus.unused,
    ),

    // ----- 商品券（关联商品 p2） -----
    CouponModel(
      id: 'cpn_p2_discount',
      userId: 'u1',
      type: CouponType.product,
      title: '专属折扣',
      description: '满50减15',
      conditionAmount: 50,
      discountAmount: 15,
      productId: 'p2',
      productName: '商品B',
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
      status: CouponStatus.unused,
    ),

    // ----- 满减券（全场通用） -----
    CouponModel(
      id: 'cpn_full_200_30',
      userId: 'u1',
      type: CouponType.fullReduction,
      title: '满200减30',
      description: '全场满200减30',
      conditionAmount: 200,
      discountAmount: 30,
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
      status: CouponStatus.unused,
    ),
    CouponModel(
      id: 'cpn_full_500_80',
      userId: 'u1',
      type: CouponType.fullReduction,
      title: '满500减80',
      description: '全场满500减80',
      conditionAmount: 500,
      discountAmount: 80,
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
      status: CouponStatus.unused,
    ),
    CouponModel(
      id: 'cpn_full_1000_200',
      userId: 'u1',
      type: CouponType.fullReduction,
      title: '满1000减200',
      description: '全场满1000减200',
      conditionAmount: 1000,
      discountAmount: 200,
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
      status: CouponStatus.unused,
    ),

    // ----- 已使用/已过期示例 -----
    CouponModel(
      id: 'cpn_used',
      userId: 'u1',
      type: CouponType.fullReduction,
      title: '历史满减券',
      description: '已使用',
      conditionAmount: 100,
      discountAmount: 15,
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 6, 1),
      status: CouponStatus.used,
    ),
    CouponModel(
      id: 'cpn_expired',
      userId: 'u1',
      type: CouponType.product,
      title: '过期券',
      description: '已过期',
      conditionAmount: 0,
      discountAmount: 5,
      productId: 'p1',
      productName: '商品A',
      validFrom: DateTime(2025, 1, 1),
      validTo: DateTime(2025, 6, 1),
      status: CouponStatus.expired,
    ),
  ];

  /// ==================== 公开方法 ====================

  /// 获取指定商品的所有可用商品券
  /// 支持按 productId 或 productName 匹配（解决 Mock 数据 ID 不一致问题）
  List<CouponModel> getProductCoupons(String productId, {String? productName}) {
    return state.where((c) {
      if (c.type != CouponType.product || !c.isUsable) return false;
      // 优先按 productId 精确匹配
      if (c.productId == productId) return true;
      // 其次按 productName 模糊匹配（支持 Mock 数据）
      if (productName != null && c.productName != null) {
        // 检查 coupon 的 productName 是否包含在商品名称中，或者反之
        if (productName.contains(c.productName!) ||
            c.productName!.contains(productName)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  /// 获取当前用户所有可用满减券
  List<CouponModel> getFullReductionCoupons() {
    return state.where((c) {
      return c.type == CouponType.fullReduction && c.isUsable;
    }).toList();
  }

  /// 获取所有未使用优惠券
  List<CouponModel> getUnusedCoupons() {
    return state.where((c) => c.status == CouponStatus.unused).toList();
  }

  /// 获取所有已使用优惠券
  List<CouponModel> getUsedCoupons() {
    return state.where((c) => c.status == CouponStatus.used).toList();
  }

  /// 获取所有已过期优惠券
  List<CouponModel> getExpiredCoupons() {
    return state.where((c) => c.status == CouponStatus.expired).toList();
  }

  /// 领取一张优惠券（从系统池中领取）
  void claimCoupon(String couponId) {
    state = state.map((c) {
      if (c.id == couponId) {
        return c.copyWith(status: CouponStatus.unused);
      }
      return c;
    }).toList();
  }

  /// 使用一张优惠券（标记为已使用）
  void useCoupon(String couponId) {
    state = state.map((c) {
      if (c.id == couponId) {
        return c.copyWith(status: CouponStatus.used);
      }
      return c;
    }).toList();
  }

  /// 检查并更新过期状态
  void refreshExpiredStatus() {
    state = state.map((c) {
      if (c.status == CouponStatus.unused && c.isExpired) {
        return c.copyWith(status: CouponStatus.expired);
      }
      return c;
    }).toList();
  }

  /// 获取优惠券总数
  int get couponCount => state.length;
}

/// 优惠券 Provider
final couponProvider = StateNotifierProvider<CouponNotifier, List<CouponModel>>(
  (ref) => CouponNotifier(),
);
