import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_exception.dart';
import '../../core/app_constants.dart';
import '../../provider/auth_provider.dart';
import '../../provider/service_providers.dart';
import '../../utils/toast.dart';

final class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

final class _LoginPageState extends ConsumerState<LoginPage> {
  final _usernameController = TextEditingController(text: '测试用户');
  final _passwordController = TextEditingController(text: '123456');
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      showToast('请输入用户名和密码');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = ref.read(dioClientProvider);
      final response = await client.post<Map<String, dynamic>>(
        '/auth/login',
        data: <String, String>{'nickname': username, 'password': password},
      );

      if (!mounted) return;

      final data = response.data;
      if (data == null) {
        setState(() => _isLoading = false);
        showToast('登录失败：服务器无响应');
        return;
      }

      final body = data['data'] as Map<String, dynamic>?;
      if (body == null) {
        setState(() => _isLoading = false);
        showToast('登录失败：${data['message'] ?? '未知错误'}');
        return;
      }

      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.login(
        body['userId'] as String,
        body['token'] as String,
        body['role'] as String,
      );

      setState(() => _isLoading = false);
      showToast('登录成功');

      if (context.mounted) {
        context.go('/mine');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showToast(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showToast('登录失败：网络错误');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.live_tv,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppDimens.paddingMd),
              const Text(
                'LiveCommerce',
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: AppDimens.paddingXs),
              const Text(
                '直播短视频带货平台',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimens.paddingXl * 2),
              TextField(
                controller: _usernameController,
                style: AppTextStyles.bodyLarge,
                decoration: InputDecoration(
                  hintText: '用户名',
                  hintStyle: AppTextStyles.bodyMedium,
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.paddingMd),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                style: AppTextStyles.bodyLarge,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: '密码',
                  hintStyle: AppTextStyles.bodyMedium,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textHint,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.paddingXl),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '登录',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: AppDimens.paddingMd),
              Text(
                '测试账号：测试用户/123456（用户） 小明数码/123456（商家）',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
