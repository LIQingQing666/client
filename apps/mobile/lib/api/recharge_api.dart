import '../core/app_constants.dart';
import 'dio_client.dart';

final class RechargeApi {
  RechargeApi({required this.client});

  final DioClient client;

  /// 创建充值订单（模拟，赠送金额在服务端生成）
  Future<Map<String, dynamic>> createRecharge({
    required String userId,
    required double amount,
    required String paymentMethod,
  }) async {
    final response = await client.post(
      '${AppConstants.baseUrl}/recharge/create',
      data: {
        'user_id': userId,
        'amount': amount,
        'payment_method': paymentMethod,
      },
    );
    final data = response.data;
    return (data['data'] as Map<String, dynamic>).cast<String, dynamic>();
  }

  /// 获取用户抖币余额
  Future<double> getCoinBalance(String userId) async {
    final response = await client.get(
      '${AppConstants.baseUrl}/users/$userId/coins',
    );
    final json = response.data;
    final data = json['data'] as Map<String, dynamic>;
    return (data['coin_balance'] as num).toDouble();
  }

  /// 获取充值记录
  Future<List<Map<String, dynamic>>> getRechargeRecords(String userId) async {
    final response = await client.get(
      '${AppConstants.baseUrl}/recharge/records/$userId',
    );
    final json = response.data;
    final data = json['data'] as Map<String, dynamic>;
    final list = data['list'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }
}
