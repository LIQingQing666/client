import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../provider/auth_provider.dart';
import '../../provider/service_providers.dart';

final class MessageDetailPage extends ConsumerStatefulWidget {
  const MessageDetailPage({super.key, required this.messageId});

  final String messageId;

  @override
  ConsumerState<MessageDetailPage> createState() => _MessageDetailPageState();
}

final class _MessageDetailPageState extends ConsumerState<MessageDetailPage> {
  Map<String, dynamic>? _message;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = ref.read(authProvider);
      final client = ref.read(dioClientProvider);
      final userId = auth.userId ?? 'u1';
      final response = await client.get<Map<String, dynamic>>('/messages/$userId');
      final body = response.data;
      if (body == null || body['data'] == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final data = body['data'] as Map<String, dynamic>;
      final list = (data['list'] as List<dynamic>?) ?? [];
      final msg = list.cast<Map<String, dynamic>>().firstWhere(
        (m) => m['id'] == widget.messageId,
        orElse: () => <String, dynamic>{},
      );
      if (mounted) {
        setState(() {
          _message = msg;
          _isLoading = false;
        });
      }
    } on Exception {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _typeLabel(String type) {
    return switch (type) {
      'system' => '系统通知',
      'like' => '点赞通知',
      'coupon' => '优惠通知',
      'order' => '订单通知',
      'follow' => '关注通知',
      _ => '消息',
    };
  }

  IconData _typeIcon(String type) {
    return switch (type) {
      'system' => Icons.campaign,
      'like' => Icons.favorite,
      'coupon' => Icons.card_giftcard,
      'order' => Icons.local_shipping,
      'follow' => Icons.person_add,
      _ => Icons.mail,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('消息详情')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _message == null || _message!.isEmpty
              ? const Center(child: Text('消息不存在', style: AppTextStyles.bodyMedium))
              : Padding(
                  padding: const EdgeInsets.all(AppDimens.paddingLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.card,
                            child: Icon(
                              _typeIcon(_message!['type'].toString()),
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppDimens.paddingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _typeLabel(_message!['type'].toString()),
                                  style: AppTextStyles.titleMedium,
                                ),
                                Text(
                                  (_message!['time'] as String?) ?? '',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.paddingXl),
                      Text(
                        (_message!['title'] as String?) ?? '',
                        style: AppTextStyles.titleLarge,
                      ),
                      const SizedBox(height: AppDimens.paddingLg),
                      Text(
                        (_message!['detail'] as String?) ?? (_message!['content'] as String?) ?? '',
                        style: AppTextStyles.bodyMedium.copyWith(height: 1.8),
                      ),
                    ],
                  ),
                ),
    );
  }
}
