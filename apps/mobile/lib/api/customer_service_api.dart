import '../core/app_constants.dart';
import '../models/customer_service_model.dart';
import 'dio_client.dart';

final class CustomerServiceApi {
  CustomerServiceApi({required this.client});

  final DioClient client;

  /// 发送消息（首次发送会自动带出客服欢迎回复）
  Future<List<CsMessageModel>> sendMessage({
    required String orderId,
    required String userId,
    required String content,
    String? msgType,
  }) async {
    final resp = await client.post(
      '${AppConstants.baseUrl}/customer-service/send',
      data: {
        'order_id': orderId,
        'user_id': userId,
        'content': content,
        if (msgType != null) 'msg_type': msgType,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    final messages = (data['data']['messages'] as List)
        .map((e) => CsMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return messages;
  }

  /// 转接人工客服
  Future<List<CsMessageModel>> transferToHuman({
    required String orderId,
    required String userId,
  }) async {
    final resp = await client.post(
      '${AppConstants.baseUrl}/customer-service/transfer',
      data: {
        'order_id': orderId,
        'user_id': userId,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    final messages = (data['data']['messages'] as List)
        .map((e) => CsMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return messages;
  }

  /// 获取聊天历史
  Future<List<CsMessageModel>> getMessages({
    required String orderId,
    String? userId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (userId != null) queryParams['userId'] = userId;
    final resp = await client.get(
      '${AppConstants.baseUrl}/customer-service/messages/$orderId',
      queryParameters: queryParams,
    );
    final data = resp.data as Map<String, dynamic>;
    final messages = (data['data']['messages'] as List)
        .map((e) => CsMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return messages;
  }

  /// 客服回复（管理后台用）
  Future<CsMessageModel> reply({
    required String orderId,
    required String userId,
    required String content,
  }) async {
    final resp = await client.post(
      '${AppConstants.baseUrl}/customer-service/reply',
      data: {
        'order_id': orderId,
        'user_id': userId,
        'content': content,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    return CsMessageModel.fromJson(data['data']['message'] as Map<String, dynamic>);
  }
}
