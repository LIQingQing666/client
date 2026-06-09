// lib/pages/admin/create_live_page.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/live_api.dart';
import '../../api/product_api.dart';
import '../../api/upload_api.dart';
import '../../core/app_constants.dart';
import '../../models/product_model.dart';
import '../../provider/service_providers.dart';

final class CreateLivePage extends ConsumerStatefulWidget {
  const CreateLivePage({super.key});

  @override
  ConsumerState<CreateLivePage> createState() => _CreateLivePageState();
}

final class _CreateLivePageState extends ConsumerState<CreateLivePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _coverUrlController = TextEditingController();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;
  List<ProductModel> _products = [];
  final Set<String> _selectedProductIds = {};
  bool _isLoadingProducts = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  // 安全的消息显示方法
  void _showMessage(String message, {Color? backgroundColor, Duration duration = const Duration(seconds: 3)}) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? AppColors.error,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // 显示加载中
  void _showLoading(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 10), // 长时间显示
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 隐藏所有 SnackBar
  void _hideMessages() {
    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);
      final result = await api.getProducts(page: 1, pageSize: 200);
      if (mounted) {
        setState(() {
          _products = result.list.where((p) => p.isActive).toList();
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _uploadCover() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() => _isUploading = true);
      _showLoading('正在上传封面...');

      final url = await ref.read(uploadApiProvider).uploadImage(image.path);
      if (mounted) {
        _hideMessages();
        _coverUrlController.text = url;
        setState(() => _isUploading = false);
        _showMessage('封面上传成功', backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        _hideMessages();
        setState(() => _isUploading = false);
        _showMessage('上传失败: $e');
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_coverUrlController.text.trim().isEmpty) {
      _showMessage('请上传直播封面');
      return;
    }
    if (_selectedProductIds.isEmpty) {
      _showMessage('请至少选择一件讲解商品');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = LiveApi(client: ref.read(dioClientProvider));
      final result = await api.createRoom(
        title: _titleController.text.trim(),
        coverUrl: _coverUrlController.text.trim(),
        productIds: _selectedProductIds.toList(),
      );

      if (!mounted) return;

      _hideMessages();
      _showMessage('直播间创建成功', backgroundColor: AppColors.success, duration: const Duration(seconds: 2));

      // 延迟返回，让用户看到成功消息
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _hideMessages();
        _showMessage('创建失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      onPopInvokedWithResult: (didPop, result) {
        if (_isSubmitting) {
          _showMessage('正在创建直播间，请稍候...');
        }
      },
      child: ScaffoldMessenger(
        key: _scaffoldMessengerKey,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('创建直播'),
            backgroundColor: AppColors.background,
            leading: _isSubmitting
                ? null // 提交时隐藏返回按钮
                : const BackButton(),
            actions: [
              TextButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
                    : const Text('创建', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('直播信息'),
                  const SizedBox(height: 16),
                  _buildTitleField(),
                  const SizedBox(height: 16),
                  _buildCoverField(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('讲解商品 (${_selectedProductIds.length}件)'),
                  const SizedBox(height: 16),
                  _buildProductGrid(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
  }

  Widget _buildTitleField() {
    return _buildLabeledField(
      label: '直播标题',
      required: true,
      child: TextFormField(
        controller: _titleController,
        decoration: _inputDecoration(hint: '如：春季新品发布会', prefixIcon: Icons.live_tv),
        validator: (v) => v?.trim().isEmpty == true ? '请输入直播标题' : null,
      ),
    );
  }

  Widget _buildCoverField() {
    return _buildLabeledField(
      label: '直播封面',
      required: true,
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: _isUploading ? null : _uploadCover,
            icon: _isUploading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload),
            label: Text(_isUploading ? '上传中...' : '上传封面'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          if (_coverUrlController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(_coverUrlController.text, height: 180, fit: BoxFit.cover),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_isLoadingProducts) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _products.map((p) {
        final isSelected = _selectedProductIds.contains(p.id);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedProductIds.remove(p.id);
              } else {
                _selectedProductIds.add(p.id);
              }
            });
          },
          child: Container(
            width: (MediaQuery.of(context).size.width - 48) / 2,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.divider,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(imageUrl: p.coverUrl, width: 40, height: 40, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall),
                ),
                if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('创建直播间', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildLabeledField({required String label, required Widget child, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
          if (required) const Text(' *', style: TextStyle(color: AppColors.error)),
        ]),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: AppColors.textHint) : null,
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
