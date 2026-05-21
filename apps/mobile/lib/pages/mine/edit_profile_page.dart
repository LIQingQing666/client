import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_constants.dart';
import '../../provider/auth_provider.dart';
import '../../provider/service_providers.dart';
import '../../provider/user_provider.dart';
import '../../utils/toast.dart';

final class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

final class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late final TextEditingController _nicknameController = TextEditingController();
  bool _isSaving = false;
  String? _avatarPath;
  bool _isPreviewVisible = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _nicknameController.text = user.nickname ?? '用户 ${ref.read(authProvider).userId ?? ""}';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
      if (file != null && mounted) {
        setState(() => _avatarPath = file.path);
      }
    } on Exception {
      showToast('选择图片失败');
    }
  }

  void _showAvatarPreview() {
    setState(() => _isPreviewVisible = true);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final auth = ref.read(authProvider);
      final client = ref.read(dioClientProvider);
      final userId = auth.userId ?? 'u1';
      final nickname = _nicknameController.text.trim();

      // If avatar selected, use the local file path for display
      String? avatarUrl = _avatarPath;
      if (_avatarPath != null) {
        await client.post<Map<String, dynamic>>('/users/$userId/avatar', data: {'avatar_url': _avatarPath!});
      }

      await client.put<Map<String, dynamic>>('/users/$userId', data: {
        'nickname': nickname,
      });

      // Update local state so mine page reflects changes
      await ref.read(userProvider.notifier).updateProfile(
        nickname: nickname,
        avatar: avatarUrl,
      );

      if (mounted) {
        showToast('保存成功');
        context.pop();
      }
    } on Exception {
      if (mounted) {
        showToast('保存失败');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Text('保存', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppDimens.paddingLg),
            children: [
              // Avatar
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showAvatarPreview,
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.card,
                        backgroundImage: _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
                        child: _avatarPath == null
                            ? Icon(Icons.person, size: 48, color: AppColors.primary)
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingSm),
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: const Text('更换头像', style: TextStyle(fontSize: 13, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.paddingXl),
              // Nickname
              const Text('昵称', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              const SizedBox(height: AppDimens.paddingSm),
              TextField(
                controller: _nicknameController,
                style: AppTextStyles.bodyLarge,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(AppDimens.paddingMd),
                ),
              ),
            ],
          ),
          // Avatar preview overlay
          if (_isPreviewVisible)
            GestureDetector(
              onTap: () => setState(() => _isPreviewVisible = false),
              child: Container(
                color: Colors.black.withOpacity(0.9),
                child: Center(
                  child: CircleAvatar(
                    radius: 120,
                    backgroundColor: AppColors.card,
                    backgroundImage: _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
                    child: _avatarPath == null
                        ? Icon(Icons.person, size: 120, color: AppColors.primary)
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
