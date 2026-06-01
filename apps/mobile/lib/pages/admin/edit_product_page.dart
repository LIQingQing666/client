import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/product_api.dart';
import '../../api/upload_api.dart';
import '../../core/app_constants.dart';
import '../../models/product_model.dart';
import '../../provider/service_providers.dart';

final class EditProductPage extends ConsumerStatefulWidget {
  const EditProductPage({super.key, required this.product});

  final ProductModel product;

  @override
  ConsumerState<EditProductPage> createState() => _EditProductPageState();
}

final class _EditProductPageState extends ConsumerState<EditProductPage> {
  final _formKey = GlobalKey<FormState>();

  // 表单控制器
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _originalPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _coverUrlController;
  late final TextEditingController _tagsController;
  late final TextEditingController _aiSalesPointController;

  // 表单状态
  late String _selectedCategory;
  List<String> _categories = [];
  late List<String> _imageUrls;
  bool _isSubmitting = false;
  bool _isLoadingCategories = true;
  bool _hasChanges = false;

  // 图片相关
  final ImagePicker _picker = ImagePicker();
  final _imageUrlController = TextEditingController();
  final _imageUrlFocusNode = FocusNode();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    // 初始化控制器
    _nameController = TextEditingController(text: p.name);
    _descriptionController = TextEditingController(text: p.description);
    _priceController = TextEditingController(text: p.price.toStringAsFixed(0));
    _originalPriceController = TextEditingController(text: p.originalPrice.toStringAsFixed(0));
    _stockController = TextEditingController(text: p.stock.toString());
    _coverUrlController = TextEditingController(text: p.coverUrl);
    _tagsController = TextEditingController(text: p.tags.join(', '));
    _aiSalesPointController = TextEditingController(text: p.aiSalesPoint);

    _selectedCategory = p.category;
    _imageUrls = List.from(p.images);

    // 监听变化
    _setupChangeListeners();

    _loadCategories();
  }

  void _setupChangeListeners() {
    _nameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _priceController.addListener(_onFieldChanged);
    _originalPriceController.addListener(_onFieldChanged);
    _stockController.addListener(_onFieldChanged);
    _coverUrlController.addListener(_onFieldChanged);
    _tagsController.addListener(_onFieldChanged);
    _aiSalesPointController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);
      final categories = await api.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  // ========== 图片上传方法 ==========

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
      setState(() => _isUploading = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('正在上传图片...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      final uploadApi = ref.read(uploadApiProvider);
      final url = await uploadApi.uploadImage(image.path);

      if (mounted) {
        setState(() {
          _imageUrls.add(url);
          _isUploading = false;
          _hasChanges = true;
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片上传成功'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
      setState(() => _isUploading = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('正在上传照片...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      final uploadApi = ref.read(uploadApiProvider);
      final url = await uploadApi.uploadImage(photo.path);

      if (mounted) {
        setState(() {
          _imageUrls.add(url);
          _isUploading = false;
          _hasChanges = true;
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('照片上传成功'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
                subtitle: const Text('选择手机中的图片'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('拍照'),
                subtitle: const Text('使用相机拍摄照片'),
                onTap: () {
                  Navigator.pop(context);
                  _takeAndUploadPhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link, color: AppColors.primary),
                title: const Text('输入图片URL'),
                subtitle: const Text('手动输入网络图片地址'),
                onTap: () {
                  Navigator.pop(context);
                  FocusScope.of(context).requestFocus(_imageUrlFocusNode);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 提交方法 ==========

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少保留一张商品图片')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
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
        coverUrl: _coverUrlController.text.trim(),
        images: _imageUrls,
        aiSalesPoint: _aiSalesPointController.text.trim().isEmpty
            ? null
            : _aiSalesPointController.text.trim(),
      );

      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);
      await api.updateProduct(id: widget.product.id, request: request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('商品更新成功'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失败: $e'),
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

  void _addImageUrl() {
    final url = _imageUrlController.text.trim();
    if (url.isEmpty) return;
    if (_imageUrls.contains(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片地址已存在')),
      );
      return;
    }
    setState(() {
      _imageUrls.add(url);
      _imageUrlController.clear();
      _hasChanges = true;
    });
  }

  void _removeImageUrl(int index) {
    setState(() {
      _imageUrls.removeAt(index);
      _hasChanges = true;
    });
  }

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
          title: const Text('编辑商品'),
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
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        body: _isLoadingCategories
            ? const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('基本信息'),
                const SizedBox(height: 16),
                _buildNameField(),
                const SizedBox(height: 16),  // 减少间距
                _buildDescriptionField(),
                const SizedBox(height: 24),

                _buildSectionTitle('价格库存'),
                const SizedBox(height: 16),
                _buildPriceFields(),
                const SizedBox(height: 16),  // 减少间距
                _buildStockField(),
                const SizedBox(height: 24),

                _buildSectionTitle('分类标签'),
                const SizedBox(height: 16),
                _buildCategoryDropdown(),
                const SizedBox(height: 16),  // 减少间距
                _buildTagsField(),
                const SizedBox(height: 24),

                _buildSectionTitle('商品图片'),
                const SizedBox(height: 16),
                _buildImageUploadButtons(),
                const SizedBox(height: 16),
                _buildCoverUrlField(),
                const SizedBox(height: 16),  // 减少间距
                _buildImageListSection(),
                const SizedBox(height: 24),

                _buildSectionTitle('AI 卖点 (选填)'),
                const SizedBox(height: 16),
                _buildAiSalesPointField(),
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
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildNameField() {
    return _buildLabeledField(
      label: '商品名称',
      child: TextFormField(
        controller: _nameController,
        decoration: _inputDecoration(
          label: '商品名称',
          hint: '请输入商品名称',
          prefixIcon: Icons.shopping_bag,
        ),
        validator: (v) => v?.trim().isEmpty == true ? '请输入商品名称' : null,
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildDescriptionField() {
    return _buildLabeledField(
      label: '商品描述',
      child: TextFormField(
        controller: _descriptionController,
        decoration: _inputDecoration(
          label: '商品描述',
          hint: '请输入商品描述',
          prefixIcon: Icons.description,
        ),
        maxLines: 3,
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildPriceFields() {
    return _buildLabeledField(
      label: '价格信息',
      child: Row(
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
          const SizedBox(width: 16),
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
      ),
    );
  }

  Widget _buildStockField() {
    return _buildLabeledField(
      label: '库存数量',
      child: TextFormField(
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
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    if (_categories.isEmpty) {
      return const Text('暂无分类数据', style: AppTextStyles.bodyMedium);
    }

    return _buildLabeledField(
      label: '商品分类',
      child: DropdownButtonFormField<String>(
        value: _categories.contains(_selectedCategory) ? _selectedCategory : null,
        decoration: _inputDecoration(
          label: '商品分类',
          prefixIcon: Icons.category,
        ),
        items: _categories.map((category) {
          return DropdownMenuItem(value: category, child: Text(category));
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedCategory = value;
              _hasChanges = true;
            });
          }
        },
        validator: (v) => v == null ? '请选择分类' : null,
      ),
    );
  }

  Widget _buildTagsField() {
    return _buildLabeledField(
      label: '商品标签',
      child: TextFormField(
        controller: _tagsController,
        decoration: _inputDecoration(
          label: '商品标签',
          hint: '多个标签用逗号分隔，如: 爆款,新品,限时',
          prefixIcon: Icons.label,
        ),
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildCoverUrlField() {
    return _buildLabeledField(
      label: '封面图片',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _coverUrlController,
            decoration: _inputDecoration(
              label: '封面图片',
              hint: '请输入封面图片URL或点击上传按钮',
              prefixIcon: Icons.image,
            ),
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

  Widget _buildImageUploadButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isUploading ? null : _showImageSourcePicker,
            icon: _isUploading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(_isUploading ? '上传中...' : '上传本地图片'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageListSection() {
    return _buildLabeledField(
      label: '商品图片列表',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_imageUrls.isNotEmpty) ...[
            _buildImageGrid(),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
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
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addImageUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _imageUrls.length,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
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
    return _buildLabeledField(
      label: 'AI 卖点描述',
      child: TextFormField(
        controller: _aiSalesPointController,
        decoration: _inputDecoration(
          label: 'AI 卖点描述',
          hint: '由AI生成的商品卖点描述，可手动修改',
          prefixIcon: Icons.auto_awesome,
        ),
        maxLines: 4,
        textInputAction: TextInputAction.done,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
            Text('正在保存...', style: TextStyle(fontSize: 16)),
          ],
        )
            : const Text(
          '保存修改',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// 带标签的字段包裹组件
  Widget _buildLabeledField({
    required String label,
    required Widget child,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签在输入框上方，左对齐，白色
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,  // 白色标签
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),  // 标签和输入框之间的间距
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      // 移除 labelText，改用独立的标签
      labelText: null,
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textHint.withValues(alpha: 0.6),
        fontSize: 14,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppColors.textHint)
          : null,
      filled: true,
      fillColor: AppColors.card,
      // 边框样式
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.divider.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      isDense: false,
      // 关键：禁用浮动标签
      floatingLabelBehavior: FloatingLabelBehavior.never,
    );
  }
}
