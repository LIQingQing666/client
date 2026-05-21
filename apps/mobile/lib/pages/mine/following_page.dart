import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../provider/auth_provider.dart';
import '../../provider/service_providers.dart';
import '../../utils/toast.dart';

final class FollowingPage extends ConsumerStatefulWidget {
  const FollowingPage({super.key});

  @override
  ConsumerState<FollowingPage> createState() => _FollowingPageState();
}

final class _FollowingPageState extends ConsumerState<FollowingPage> {
  List<Map<String, dynamic>> _list = [];
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
      final response = await client.get<Map<String, dynamic>>('/users/$userId/following');
      final body = response.data;
      if (body == null || body['data'] == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final data = body['data'] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _list = (data['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          _isLoading = false;
        });
      }
    } on Exception {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unfollow(String targetId) async {
    try {
      final auth = ref.read(authProvider);
      final client = ref.read(dioClientProvider);
      final userId = auth.userId ?? 'u1';
      await client.delete<Map<String, dynamic>>('/users/$targetId/follow', data: {'user_id': userId});
      if (!mounted) return;
      setState(() => _list.removeWhere((e) => e['id'] == targetId));
      showToast('已取消关注');
    } on Exception {
      showToast('操作失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('我的关注')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _list.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_disabled, size: 48, color: AppColors.textHint),
                      SizedBox(height: AppDimens.paddingMd),
                      Text('还没有关注任何人', style: AppTextStyles.titleMedium),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
                  itemCount: _list.length,
                  itemBuilder: (context, index) {
                    final user = _list[index];
                    final name = (user['nickname'] as String?) ?? '用户';
                    final avatar = (user['avatar'] as String?) ?? '';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.card,
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty ? Text(name.isNotEmpty ? name[0] : '?') : null,
                      ),
                      title: Text(name, style: AppTextStyles.bodyLarge),
                      trailing: GestureDetector(
                        onTap: () => _unfollow(user['id'].toString()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingMd, vertical: AppDimens.paddingSm),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                          ),
                          child: const Text('取消关注', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
