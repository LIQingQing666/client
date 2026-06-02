import '../models/live_model.dart';
import '../models/product_model.dart';
import 'dio_client.dart';

final class LiveApi {
  const LiveApi({required this.client});

  final DioClient client;

  Future<List<LiveRoomInfo>> getRooms() async {
    final response = await client.get<Map<String, dynamic>>('/live/rooms');
    final data = response.data!['data'] as Map<String, dynamic>;
    final list = data['list'] as List<dynamic>;
    return list
        .map((e) => LiveRoomInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LiveRoomDetail> getRoomDetail(String roomId) async {
    final response = await client.get<Map<String, dynamic>>(
      '/live/rooms/$roomId',
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return LiveRoomDetail.fromJson(data);
  }

  /// 发送礼物（扣减抖币）
  Future<Map<String, dynamic>> sendGift({
    required String userId,
    required String giftId,
    required String giftName,
    required int price,
    required String roomId,
  }) async {
    final response = await client.post<Map<String, dynamic>>('/live/gift', data: {
      'user_id': userId,
      'gift_id': giftId,
      'gift_name': giftName,
      'price': price,
      'room_id': roomId,
    });
    return response.data!['data'] as Map<String, dynamic>;
  }
}

final class LiveRoomDetail {
  const LiveRoomDetail({
    required this.room,
    required this.products,
    required this.coupons,
  });

  factory LiveRoomDetail.fromJson(Map<String, dynamic> json) {
    final rawProducts = (json['products'] as List<dynamic>?) ?? [];
    final rawCoupons = (json['coupons'] as List<dynamic>?) ?? [];
    return LiveRoomDetail(
      room: LiveRoomInfo.fromJson(json),
      products: rawProducts
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      coupons: rawCoupons
          .map((e) => LiveCoupon.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final LiveRoomInfo room;
  final List<ProductModel> products;
  final List<LiveCoupon> coupons;
}

final class LiveCoupon {
  const LiveCoupon({
    required this.id,
    required this.title,
    required this.amount,
    required this.minOrder,
    required this.totalCount,
    required this.usedCount,
    required this.endTime,
  });

  factory LiveCoupon.fromJson(Map<String, dynamic> json) {
    return LiveCoupon(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      minOrder: (json['min_order'] as num?)?.toDouble() ?? 0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      usedCount: (json['used_count'] as num?)?.toInt() ?? 0,
      endTime: (json['end_time'] as String?) ?? '',
    );
  }

  final String id;
  final String title;
  final double amount;
  final double minOrder;
  final int totalCount;
  final int usedCount;
  final String endTime;

  int get remaining => totalCount - usedCount;
  bool get isAvailable => remaining > 0;
}
