/// 优惠券类型
enum CouponType {
  /// 商品券 - 仅限特定商品使用
  product,

  /// 满减券 - 购物车满减
  fullReduction,
}

/// 优惠券状态
enum CouponStatus {
  /// 未使用
  unused,

  /// 已使用
  used,

  /// 已过期
  expired,
}

/// 优惠券数据模型
final class CouponModel {
  const CouponModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.conditionAmount,
    required this.discountAmount,
    this.productId,
    this.productName,
    required this.validFrom,
    required this.validTo,
    required this.status,
  });

  /// 优惠券ID
  final String id;

  /// 所属用户ID
  final String userId;

  /// 优惠券类型
  final CouponType type;

  /// 券标题，如"新人专享"、"爆品券"
  final String title;

  /// 描述，如"满200减30"
  final String description;

  /// 门槛金额（满减券适用），0表示无门槛
  final double conditionAmount;

  /// 优惠金额
  final double discountAmount;

  /// 商品券关联的商品ID
  final String? productId;

  /// 商品名称快照
  final String? productName;

  /// 有效期开始
  final DateTime validFrom;

  /// 有效期结束
  final DateTime validTo;

  /// 状态
  final CouponStatus status;

  /// 优惠券是否可用（未使用且在有效期内）
  bool get isUsable =>
      status == CouponStatus.unused &&
      DateTime.now().isAfter(validFrom) &&
      DateTime.now().isBefore(validTo);

  /// 是否已过期
  bool get isExpired => DateTime.now().isAfter(validTo);

  /// 获取券后价（针对商品券）
  double getPriceAfterDiscount(double originalPrice) {
    final discounted = originalPrice - discountAmount;
    return discounted < 0 ? 0 : discounted;
  }

  /// 判断是否满足门槛
  bool meetsCondition(double totalAmount) {
    return totalAmount >= conditionAmount;
  }

  /// 序列化
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type.name,
        'title': title,
        'description': description,
        'condition_amount': conditionAmount,
        'discount_amount': discountAmount,
        'product_id': productId,
        'product_name': productName,
        'valid_from': validFrom.toIso8601String(),
        'valid_to': validTo.toIso8601String(),
        'status': status.name,
      };

  /// 反序列化
  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: CouponType.values.byName(json['type'] as String),
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      conditionAmount: (json['condition_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String?,
      validFrom: DateTime.parse(json['valid_from'] as String),
      validTo: DateTime.parse(json['valid_to'] as String),
      status: CouponStatus.values.byName(json['status'] as String),
    );
  }

  /// 用新状态复制一份
  CouponModel copyWith({CouponStatus? status}) {
    return CouponModel(
      id: id,
      userId: userId,
      type: type,
      title: title,
      description: description,
      conditionAmount: conditionAmount,
      discountAmount: discountAmount,
      productId: productId,
      productName: productName,
      validFrom: validFrom,
      validTo: validTo,
      status: status ?? this.status,
    );
  }
}
