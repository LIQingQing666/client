import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../provider/auth_provider.dart';
import '../../provider/service_providers.dart';

final class MessagePage extends ConsumerStatefulWidget {
  const MessagePage({super.key});

  @override
  ConsumerState<MessagePage> createState() => _MessagePageState();
}

final class _MessagePageState extends ConsumerState<MessagePage> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
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
      if (mounted) {
        setState(() {
          _messages = (data['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          _isLoading = false;
        });
      }
    } on Exception {
      if (mounted) setState(() => _isLoading = false);
    }
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
      appBar: AppBar(title: const Text('消息')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _messages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mail_outline, size: 64, color: AppColors.textHint),
                      SizedBox(height: AppDimens.paddingMd),
                      Text('暂无消息', style: AppTextStyles.titleMedium),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isRead = (msg['isRead'] as bool?) ?? true;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.card,
                        child: Icon(_typeIcon(msg['type'].toString()), color: AppColors.primary, size: 20),
                      ),
                      title: Row(
                        children: [
                          Text(msg['title'].toString(), style: AppTextStyles.bodyLarge),
                          if (!isRead)
                            Container(
                              margin: const EdgeInsets.only(left: AppDimens.paddingSm),
                              width: 8, height: 8,
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(msg['content'].toString(), style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(msg['time'].toString(), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                        ],
                      ),
                      onTap: () {
                        context.pushNamed('messageDetail', pathParameters: {'id': msg['id'].toString()});
                      },
                    );
                  },
                ),
    );
  }
}
