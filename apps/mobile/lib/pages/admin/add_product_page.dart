import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/product_api.dart';
import '../../api/upload_api.dart';
import '../../core/app_constants.dart';
import '../../provider/service_providers.dart';

final class AddProductPage extends ConsumerStatefulWidget {
  const AddProductPage({super.key});

  @override
  ConsumerState<AddProductPage> createState() => _AddProductPageState();
}

final class _AddProductPageState extends ConsumerState<AddProductPage> {
  final _formKey = GlobalKey<FormState>();

  // 表单控制器
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _coverUrlController = TextEditingController();
  final _tagsController = TextEditingController();
  final _aiSalesPointController = TextEditingController();

  // 表单状态
  String _selectedCategory = '';
  List<String> _categories = [];
  List<String> _imageUrls = [];
  bool _isSubmitting = false;
  bool _isLoadingCategories = true;
  bool _isGeneratingAi = false;

  // 图片相关
  final ImagePicker _picker = ImagePicker();
  final _imageUrlController = TextEditingController();
  final _imageUrlFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);
      final categories = await api.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          if (categories.isNotEmpty) {
            _selectedCategory = categories.first;
          }
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  // ========== 图片上传相关方法 ==========

  /// 从相册选择并上传图片
  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在上传图片...')),
      );

      // 使用 ref 读取 uploadApiProvider
      final uploadApi = ref.read(uploadApiProvider);
      final url = await uploadApi.uploadImage(image.path);

      if (mounted) {
        setState(() {
          _imageUrls.add(url);
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片上传成功'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('图片上传失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 拍照并上传
  Future<void> _takeAndUploadPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在上传照片...')),
      );

      final uploadApi = ref.read(uploadApiProvider);
      final url = await uploadApi.uploadImage(photo.path);

      if (mounted) {
        setState(() {
          _imageUrls.add(url);
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('照片上传成功'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 显示图片选择方式
  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _takeAndUploadPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('输入图片URL'),
              onTap: () {
                Navigator.pop(context);
                FocusScope.of(context).requestFocus(_imageUrlFocusNode);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ========== 提交和 AI 卖点 ==========

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty && _coverUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一张商品图片或封面图')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final coverUrl = _coverUrlController.text.trim().isEmpty
          ? _imageUrls.first
          : _coverUrlController.text.trim();

      final request = ProductCreateRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        originalPrice: double.parse(_originalPriceController.text.trim()),
        stock: int.parse(_stockController.text.trim()),
        category: _selectedCategory,
        tags: _tagsController.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        coverUrl: coverUrl,
        images: _imageUrls.isEmpty && _coverUrlController.text.trim().isNotEmpty
            ? [_coverUrlController.text.trim()]
            : _imageUrls,
        aiSalesPoint: _aiSalesPointController.text.trim().isEmpty
            ? null
            : _aiSalesPointController.text.trim(),
      );

      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);
      await api.createProduct(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('商品添加成功'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _generateAiSalesPoint() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入商品名称')),
      );
      return;
    }

    setState(() => _isGeneratingAi = true);

    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final salesPoint = await api.generateAiSalesPoint(
        name: name,
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        tags: tags.isEmpty ? null : tags,
      );

      if (mounted) {
        _aiSalesPointController.text = salesPoint;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI 卖点生成成功'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('生成失败，请手动输入'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAi = false);
      }
    }
  }

  // ========== URL 图片管理 ==========

  void _addImageUrl() {
    final url = _imageUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入图片地址')),
      );
      return;
    }
    if (_imageUrls.contains(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片地址已存在')),
      );
      return;
    }
    setState(() {
      _imageUrls.add(url);
      _imageUrlController.clear();
    });
  }

  void _removeImageUrl(int index) {
    setState(() => _imageUrls.removeAt(index));
  }

  // ========== 释放资源 ==========

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _stockController.dispose();
    _coverUrlController.dispose();
    _tagsController.dispose();
    _aiSalesPointController.dispose();
    _imageUrlController.dispose();
    _imageUrlFocusNode.dispose();
    super.dispose();
  }

  // ========== UI 构建 ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('添加商品'),
        backgroundColor: AppColors.background,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
                : const Text(
              '保存',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: _isLoadingCategories
          ? const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingLg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('基本信息'),
              const SizedBox(height: AppDimens.paddingMd),
              _buildNameField(),
              const SizedBox(height: AppDimens.paddingMd),
              _buildDescriptionField(),
              const SizedBox(height: AppDimens.paddingLg),

              _buildSectionTitle('价格库存'),
              const SizedBox(height: AppDimens.paddingMd),
              _buildPriceFields(),
              const SizedBox(height: AppDimens.paddingMd),
              _buildStockField(),
              const SizedBox(height: AppDimens.paddingLg),

              _buildSectionTitle('分类标签'),
              const SizedBox(height: AppDimens.paddingMd),
              _buildCategoryDropdown(),
              const SizedBox(height: AppDimens.paddingMd),
              _buildTagsField(),
              const SizedBox(height: AppDimens.paddingLg),

              _buildSectionTitle('商品图片'),
              const SizedBox(height: AppDimens.paddingMd),
              _buildCoverUrlField(),
              const SizedBox(height: AppDimens.paddingMd),
              _buildImageListSection(),
              const SizedBox(height: AppDimens.paddingLg),

              _buildSectionTitle('AI 卖点 (选填)'),
              const SizedBox(height: AppDimens.paddingMd),
              _buildAiSalesPointField(),
              const SizedBox(height: AppDimens.paddingLg),

              _buildSubmitButton(),
              const SizedBox(height: AppDimens.paddingLg),
            ],
          ),
        ),
      ),
    );
  }

  // ========== UI 组件 ==========

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTextStyles.titleMedium);
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: _inputDecoration(
        label: '商品名称',
        hint: '请输入商品名称',
        prefixIcon: Icons.shopping_bag,
      ),
      validator: (v) => v?.trim().isEmpty == true ? '请输入商品名称' : null,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: _inputDecoration(
        label: '商品描述',
        hint: '请输入商品描述',
        prefixIcon: Icons.description,
      ),
      maxLines: 3,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildPriceFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _priceController,
            decoration: _inputDecoration(
              label: '售价',
              hint: '0.00',
              prefixIcon: Icons.sell,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v?.trim().isEmpty == true) return '请输入售价';
              if (double.tryParse(v!.trim()) == null) return '请输入有效价格';
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: AppDimens.paddingMd),
        Expanded(
          child: TextFormField(
            controller: _originalPriceController,
            decoration: _inputDecoration(
              label: '原价',
              hint: '0.00',
              prefixIcon: Icons.label_off,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v?.trim().isEmpty == true) return '请输入原价';
              if (double.tryParse(v!.trim()) == null) return '请输入有效价格';
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
        ),
      ],
    );
  }

  Widget _buildStockField() {
    return TextFormField(
      controller: _stockController,
      decoration: _inputDecoration(
        label: '库存数量',
        hint: '0',
        prefixIcon: Icons.inventory,
      ),
      keyboardType: TextInputType.number,
      validator: (v) {
        if (v?.trim().isEmpty == true) return '请输入库存数量';
        if (int.tryParse(v!.trim()) == null) return '请输入有效数量';
        return null;
      },
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildCategoryDropdown() {
    if (_categories.isEmpty) {
      return const Text('暂无分类数据', style: AppTextStyles.bodyMedium);
    }

    return DropdownButtonFormField<String>(
      value: _categories.contains(_selectedCategory) ? _selectedCategory : null,
      decoration: _inputDecoration(
        label: '商品分类',
        prefixIcon: Icons.category,
      ),
      items: _categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedCategory = value);
        }
      },
      validator: (v) => v == null ? '请选择分类' : null,
    );
  }

  Widget _buildTagsField() {
    return TextFormField(
      controller: _tagsController,
      decoration: _inputDecoration(
        label: '商品标签',
        hint: '多个标签用逗号分隔，如: 爆款,新品,限时',
        prefixIcon: Icons.label,
      ),
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildCoverUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _coverUrlController,
          decoration: _inputDecoration(
            label: '封面图片地址',
            hint: '请输入封面图片URL',
            prefixIcon: Icons.image,
          ),
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        if (_coverUrlController.text.trim().isNotEmpty) ...[
          const SizedBox(height: AppDimens.paddingSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: CachedNetworkImage(
              imageUrl: _coverUrlController.text.trim(),
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                height: 180,
                color: AppColors.divider,
                child: const Center(
                  child: Text('图片加载失败', style: AppTextStyles.bodySmall),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 已上传/添加的图片网格
        if (_imageUrls.isNotEmpty) ...[
          _buildImageGrid(),
          const SizedBox(height: AppDimens.paddingMd),
        ],

        // 操作按钮行
        Row(
          children: [
            // 上传按钮（从相册/拍照）
            OutlinedButton.icon(
              onPressed: _showImageSourcePicker,
              icon: const Icon(Icons.cloud_upload, size: 18),
              label: const Text('上传'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.paddingMd,
                  vertical: AppDimens.paddingSm,
                ),
              ),
            ),
            const SizedBox(width: AppDimens.paddingSm),

            // URL 输入框
            Expanded(
              child: TextFormField(
                controller: _imageUrlController,
                focusNode: _imageUrlFocusNode,
                decoration: _inputDecoration(
                  label: '图片URL',
                  hint: 'https://...',
                  prefixIcon: Icons.link,
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _addImageUrl(),
              ),
            ),
            const SizedBox(width: AppDimens.paddingSm),

            // 添加按钮
            ElevatedButton(
              onPressed: _addImageUrl,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.paddingMd,
                  vertical: AppDimens.paddingMd,
                ),
              ),
              child: const Text('添加'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppDimens.paddingSm,
        mainAxisSpacing: AppDimens.paddingSm,
        childAspectRatio: 1,
      ),
      itemCount: _imageUrls.length,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              child: CachedNetworkImage(
                imageUrl: _imageUrls[index],
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.divider,
                  child: const Icon(
                    Icons.broken_image,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeImageUrl(index),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAiSalesPointField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('AI 自动生成卖点', style: AppTextStyles.bodySmall),
            ),
            TextButton.icon(
              onPressed: _isGeneratingAi ? null : _generateAiSalesPoint,
              icon: _isGeneratingAi
                  ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(_isGeneratingAi ? '生成中...' : '生成卖点'),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.paddingSm),
        TextFormField(
          controller: _aiSalesPointController,
          decoration: _inputDecoration(
            label: 'AI 卖点描述',
            hint: '由AI生成的商品卖点描述，可手动修改',
            prefixIcon: Icons.auto_awesome,
          ),
          maxLines: 4,
          textInputAction: TextInputAction.done,
        ),
      ],
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
        ),
        child: _isSubmitting
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('正在提交...'),
          ],
        )
            : const Text(
          '确认添加',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: AppTextStyles.bodySmall,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20)
          : null,
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingMd,
        vertical: AppDimens.paddingMd,
      ),
    );
  }
}
