final class OrderModel {
  const OrderModel({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.discountAmount,
    required this.payAmount,
    required this.status,
    required this.address,
    required this.items,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ?? [];
    final rawAddress = (json['address'] as Map<String, dynamic>?) ?? {};
    return OrderModel(
      id: json['id'] as String,
      userId: (json['user_id'] as String?) ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      payAmount: (json['pay_amount'] as num?)?.toDouble() ?? 0,
      status: (json['status'] as String?) ?? 'pending',
      address: OrderAddress.fromJson(rawAddress),
      items: rawItems
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }

  final String id;
  final String userId;
  final double totalAmount;
  final double discountAmount;
  final double payAmount;
  final String status;
  final OrderAddress address;
  final List<OrderItem> items;
  final String createdAt;

  String get statusText {
    return switch (status) {
      'pending' => '待支付',
      'paid' => '已支付',
      'shipped' => '已发货',
      'completed' => '已完成',
      'cancelled' => '已取消',
      'payment_failed' => '支付失败',
      _ => status,
    };
  }
}

final class OrderAddress {
  const OrderAddress({
    this.name = '',
    this.phone = '',
    this.detail = '',
  });

  factory OrderAddress.fromJson(Map<String, dynamic> json) {
    return OrderAddress(
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      detail: (json['detail'] as String?) ?? '',
    );
  }

  final String name;
  final String phone;
  final String detail;

  Map<String, dynamic> toJson() {
    return {'name': name, 'phone': phone, 'detail': detail};
  }
}

final class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.productCover,
    required this.productPrice,
    required this.spec,
    required this.quantity,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: (json['product_id'] as String?) ?? '',
      productName: (json['product_name'] as String?) ?? '',
      productCover: (json['product_cover'] as String?) ?? '',
      productPrice: (json['product_price'] as num?)?.toDouble() ?? 0,
      spec: (json['spec'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }

  final String productId;
  final String productName;
  final String productCover;
  final double productPrice;
  final String spec;
  final int quantity;
  final double subtotal;
}
