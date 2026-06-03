/// 客服消息模型
final class CsMessageModel {
  final String id;
  final String orderId;
  final String userId;
  final String senderType; // 'user' | 'admin' | 'ai' | 'system'
  final String content;
  final String msgType; // 'text' | 'order_card'
  final String createdAt;

  const CsMessageModel({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.senderType,
    required this.content,
    required this.msgType,
    required this.createdAt,
  });

  factory CsMessageModel.fromJson(Map<String, dynamic> json) {
    return CsMessageModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      userId: json['user_id'] as String,
      senderType: json['sender_type'] as String,
      content: json['content'] as String,
      msgType: json['msg_type'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  bool get isUser => senderType == 'user';
  bool get isAdmin => senderType == 'admin';
  bool get isAi => senderType == 'ai';
  bool get isSystem => senderType == 'system';
}
