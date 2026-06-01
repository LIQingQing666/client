import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/product_api.dart';
import '../../core/app_constants.dart';
import '../../models/product_model.dart';
import '../../provider/service_providers.dart';
import 'edit_product_page.dart';

final class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

final class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  ProductModel? _product;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);
      final result = await api.getProductDetail(widget.productId);
      setState(() {
        _product = result.product;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('商品详情'),
        backgroundColor: AppColors.background,
        actions: [
          // 编辑按钮
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑商品',
            onPressed: () async {
              if (_product == null) return;

              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProductPage(product: _product!),
                ),
              );

              // 编辑成功后刷新页面
              if (result == true) {
                _load();
              }
            },
          ),
          // 更多操作
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'delete':
                  _deleteProduct();
                  break;
                case 'share':
                // 分享功能
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 8),
                    Text('分享'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('删除', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: AppDimens.paddingMd),
                      Text(_error!, style: AppTextStyles.bodyMedium),
                      const SizedBox(height: AppDimens.paddingMd),
                      ElevatedButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除商品"${_product!.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);
      await api.deleteProduct(widget.productId);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('商品已删除'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        // 关键：返回 true 表示商品已删除
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppDimens.paddingMd),
          Text(_error!, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppDimens.paddingMd),
          ElevatedButton(onPressed: _load, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final p = _product!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: CachedNetworkImage(
              imageUrl: p.coverUrl,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(height: 200, color: AppColors.card),
              errorWidget: (_, __, ___) => Container(height: 200, color: AppColors.card),
            ),
          ),
          const SizedBox(height: AppDimens.paddingLg),
          _Field(label: '商品名称', value: p.name),
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: AppDimens.paddingMd),
            _Field(label: '描述', value: p.description),
          ],
          const SizedBox(height: AppDimens.paddingMd),
          Row(
            children: [
              Expanded(child: _Field(label: '售价', value: '¥${p.price.toStringAsFixed(0)}')),
              Expanded(child: _Field(label: '原价', value: '¥${p.originalPrice.toStringAsFixed(0)}')),
            ],
          ),
          const SizedBox(height: AppDimens.paddingMd),
          Row(
            children: [
              Expanded(child: _Field(label: '库存', value: p.stock.toString())),
              Expanded(child: _Field(label: '销量', value: p.sales.toString())),
            ],
          ),
          const SizedBox(height: AppDimens.paddingMd),
          _Field(label: '分类', value: p.category),
          if (p.tags.isNotEmpty) ...[
            const SizedBox(height: AppDimens.paddingMd),
            _Field(label: '标签', value: p.tags.join(', ')),
          ],
          if (p.aiSalesPoint.isNotEmpty) ...[
            const SizedBox(height: AppDimens.paddingLg),
            const Text('AI 卖点', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppDimens.paddingSm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimens.paddingMd),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.aiSalesPoint, style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
            ),
          ],
          if (p.images.isNotEmpty) ...[
            const SizedBox(height: AppDimens.paddingLg),
            const Text('商品图片', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppDimens.paddingSm),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: p.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppDimens.paddingSm),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: CachedNetworkImage(
                    imageUrl: p.images[index],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 80, height: 80, color: AppColors.card),
                    errorWidget: (_, __, ___) => Container(width: 80, height: 80, color: AppColors.card),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimens.paddingMd),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: Text(value, style: AppTextStyles.bodyLarge),
        ),
      ],
    );
  }
}
