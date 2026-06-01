import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/product_api.dart';
import '../../api/upload_api.dart';
import '../../api/video_api.dart';
import '../../core/app_constants.dart';
import '../../models/product_model.dart';
import '../../models/video_create_request.dart';
import '../../models/video_model.dart';
import '../../provider/service_providers.dart';

final class EditVideoPage extends ConsumerStatefulWidget {
  const EditVideoPage({super.key, required this.video});

  final VideoModel video;

  @override
  ConsumerState<EditVideoPage> createState() => _EditVideoPageState();
}

final class _EditVideoPageState extends ConsumerState<EditVideoPage> {
  final _formKey = GlobalKey<FormState>();

  // 表单控制器
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _coverUrlController;
  late final TextEditingController _videoUrlController;
  late final TextEditingController _tagsController;
  late final TextEditingController _durationController;

  // 视频状态
  late String _videoStatus;

  // 关联商品
  List<ProductModel> _availableProducts = [];
  final Set<String> _selectedProductIds = {};
  bool _isLoadingProducts = false;

  // 图片上传
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // 提交状态
  bool _isSubmitting = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final v = widget.video;

    // 初始化控制器
    _titleController = TextEditingController(text: v.title);
    _descriptionController = TextEditingController(text: v.description);
    _coverUrlController = TextEditingController(text: v.coverUrl);
    _videoUrlController = TextEditingController(text: v.videoUrl);
    _tagsController = TextEditingController(text: v.tags.join(', '));
    _durationController = TextEditingController(text: v.duration.toString());
    _videoStatus = v.status;

    // 监听变化
    _setupChangeListeners();

    _loadProducts();
  }

  void _setupChangeListeners() {
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _coverUrlController.addListener(_onFieldChanged);
    _videoUrlController.addListener(_onFieldChanged);
    _tagsController.addListener(_onFieldChanged);
    _durationController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);
      final result = await api.getProducts(page: 1, pageSize: 200);
      if (mounted) {
        setState(() {
          _availableProducts = result.list.where((p) => p.isActive).toList();
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  // ========== 图片上传 ==========

  Future<void> _pickAndUploadImage() async {
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('正在上传封面...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      final uploadApi = ref.read(uploadApiProvider);
      final url = await uploadApi.uploadImage(image.path);

      if (mounted) {
        setState(() {
          _coverUrlController.text = url;
          _isUploading = false;
          _hasChanges = true;
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('封面上传成功'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link, color: AppColors.primary),
                title: const Text('输入图片URL'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 提交 ==========

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final request = VideoCreateRequest(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        coverUrl: _coverUrlController.text.trim(),
        videoUrl: _videoUrlController.text.trim(),
        authorName: widget.video.authorName,
        authorId: widget.video.authorId,
        tags: _tagsController.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        linkedProductIds: _selectedProductIds.toList(),
        duration: int.tryParse(_durationController.text.trim()) ?? 0,
        status: _videoStatus,
      );

      final client = ref.read(dioClientProvider);
      final api = VideoApi(client: client);
      await api.updateVideo(id: widget.video.id, request: request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('视频更新成功'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃修改？'),
        content: const Text('你有未保存的修改，确定要离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _coverUrlController.dispose();
    _videoUrlController.dispose();
    _tagsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('编辑视频'),
          backgroundColor: AppColors.background,
          actions: [
            TextButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Text('保存', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
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
                _buildSectionTitle('基本信息'),
                const SizedBox(height: 16),
                _buildTitleField(),
                const SizedBox(height: 16),
                _buildDescriptionField(),
                const SizedBox(height: 24),

                _buildSectionTitle('作者信息'),
                const SizedBox(height: 16),
                _buildAuthorInfoCard(),
                const SizedBox(height: 24),

                _buildSectionTitle('视频状态'),
                const SizedBox(height: 16),
                _buildStatusSelector(),
                const SizedBox(height: 24),

                _buildSectionTitle('视频封面'),
                const SizedBox(height: 16),
                _buildCoverUploadButton(),
                const SizedBox(height: 12),
                _buildCoverUrlField(),
                const SizedBox(height: 24),

                _buildSectionTitle('视频信息'),
                const SizedBox(height: 16),
                _buildVideoUrlField(),
                const SizedBox(height: 16),
                _buildDurationField(),
                const SizedBox(height: 16),
                _buildTagsField(),
                const SizedBox(height: 24),

                _buildSectionTitle('关联商品'),
                const SizedBox(height: 16),
                _buildProductSelector(),
                const SizedBox(height: 32),

                _buildSubmitButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== UI 组件 ==========

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
  }

  Widget _buildTitleField() {
    return _buildLabeledField(
      label: '视频标题',
      required: true,
      child: TextFormField(
        controller: _titleController,
        decoration: _inputDecoration(hint: '请输入视频标题', prefixIcon: Icons.title),
        validator: (v) => v?.trim().isEmpty == true ? '请输入视频标题' : null,
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildDescriptionField() {
    return _buildLabeledField(
      label: '视频描述',
      child: TextFormField(
        controller: _descriptionController,
        decoration: _inputDecoration(hint: '请输入视频描述', prefixIcon: Icons.description),
        maxLines: 3,
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildAuthorInfoCard() {
    final v = widget.video;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFE8453C), Color(0xFFFF6B35)]),
            ),
            child: Center(
              child: Text(
                v.authorName.isNotEmpty ? v.authorName[0].toUpperCase() : '商',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.authorName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.verified, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('视频作者', style: TextStyle(fontSize: 12, color: AppColors.textHint.withValues(alpha: 0.8))),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.lock, size: 18, color: AppColors.textHint.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _buildStatusOption(
            value: 'draft',
            title: '草稿',
            subtitle: '仅自己可见，不会在首页展示',
            icon: Icons.edit_note,
            color: const Color(0xFFFF9800),
          ),
          const Divider(height: 1),
          _buildStatusOption(
            value: 'published',
            title: '已发布',
            subtitle: '公开可见，会展示在首页和推荐中',
            icon: Icons.publish,
            color: const Color(0xFF4CAF50),
          ),
          const Divider(height: 1),
          _buildStatusOption(
            value: 'inactive',
            title: '已下架',
            subtitle: '暂时隐藏，不会公开显示',
            icon: Icons.visibility_off,
            color: const Color(0xFF9E9E9E),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _videoStatus == value;

    return InkWell(
      onTap: () {
        setState(() {
          _videoStatus = value;
          _hasChanges = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: value == 'draft'
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : value == 'inactive'
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.15) : AppColors.divider.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? color : AppColors.textHint, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? color : AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : AppColors.textHint.withValues(alpha: 0.4),
                  width: isSelected ? 0 : 2,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverUploadButton() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isUploading ? null : _showImageSourcePicker,
            icon: _isUploading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(_isUploading ? '上传中...' : '更换封面图片'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverUrlField() {
    return _buildLabeledField(
      label: '封面图片地址',
      required: true,
      child: Column(
        children: [
          TextFormField(
            controller: _coverUrlController,
            decoration: _inputDecoration(hint: '请输入封面图片URL', prefixIcon: Icons.image),
            validator: (v) => v?.trim().isEmpty == true ? '请输入封面图片地址' : null,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          if (_coverUrlController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: _coverUrlController.text.trim(),
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  height: 180,
                  color: AppColors.divider,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, size: 32, color: AppColors.textHint),
                        SizedBox(height: 4),
                        Text('图片加载失败', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoUrlField() {
    return _buildLabeledField(
      label: '视频地址',
      required: true,
      child: TextFormField(
        controller: _videoUrlController,
        decoration: _inputDecoration(hint: '请输入视频URL', prefixIcon: Icons.videocam),
        validator: (v) => v?.trim().isEmpty == true ? '请输入视频地址' : null,
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildDurationField() {
    return _buildLabeledField(
      label: '视频时长（秒）',
      child: TextFormField(
        controller: _durationController,
        decoration: _inputDecoration(hint: '如：120', prefixIcon: Icons.timer),
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildTagsField() {
    return _buildLabeledField(
      label: '视频标签',
      child: TextFormField(
        controller: _tagsController,
        decoration: _inputDecoration(hint: '多个标签用逗号分隔，如: 教程,测评,推荐', prefixIcon: Icons.label),
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildProductSelector() {
    if (_isLoadingProducts) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primary)));
    }

    if (_availableProducts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8)),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textHint),
            SizedBox(width: 8),
            Text('暂无可关联的商品', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          if (_selectedProductIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.shopping_bag, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('已选择 ${_selectedProductIds.length} 件商品',
                      style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _availableProducts.length,
            itemBuilder: (context, index) {
              final product = _availableProducts[index];
              final isSelected = _selectedProductIds.contains(product.id);
              return CheckboxListTile(
                value: isSelected,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedProductIds.add(product.id);
                    } else {
                      _selectedProductIds.remove(product.id);
                    }
                    _hasChanges = true;
                  });
                },
                title: Text(product.name, style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('¥${product.price.toStringAsFixed(0)} | ${product.category}', style: AppTextStyles.bodySmall),
                secondary: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(imageUrl: product.coverUrl, width: 40, height: 40, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(width: 40, height: 40, color: AppColors.divider)),
                ),
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.trailing,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                dense: true,
              );
            },
          ),
        ],
      ),
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
        child: _isSubmitting
            ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('正在保存...', style: TextStyle(fontSize: 16)),
        ])
            : const Text('保存修改', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ========== 辅助方法 ==========

  Widget _buildLabeledField({required String label, required Widget child, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
          if (required) const Text(' *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.error)),
        ]),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.6), fontSize: 14),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: AppColors.textHint) : null,
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5), width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error, width: 1)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
