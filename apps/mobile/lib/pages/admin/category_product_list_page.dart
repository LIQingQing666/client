import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/product_api.dart';
import '../../core/app_constants.dart';
import '../../models/product_model.dart';
import '../../provider/service_providers.dart';

final class CategoryProductListPage extends ConsumerStatefulWidget {
  const CategoryProductListPage({super.key, required this.category});

  final String category;

  @override
  ConsumerState<CategoryProductListPage> createState() => _CategoryProductListPageState();
}

final class _CategoryProductListPageState extends ConsumerState<CategoryProductListPage> {
  List<ProductModel> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);
      final result = await api.getProducts(page: 1, pageSize: 50);
      if (mounted) {
        setState(() {
          _products = result.list.where((p) => p.category == widget.category).toList();
          _isLoading = false;
        });
      }
    } on Exception {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('${widget.category} - 商品列表')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _products.isEmpty
              ? const Center(child: Text('暂无商品', style: AppTextStyles.bodyMedium))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppDimens.paddingLg),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    return GestureDetector(
                      onTap: () => context.pushNamed(
                        'productDetail',
                        pathParameters: {'id': p.id},
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppDimens.paddingSm),
                        padding: const EdgeInsets.all(AppDimens.paddingMd),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                              child: CachedNetworkImage(
                                imageUrl: p.coverUrl,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(width: 56, height: 56, color: AppColors.divider),
                              ),
                            ),
                            const SizedBox(width: AppDimens.paddingMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: AppTextStyles.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('¥${p.price.toStringAsFixed(0)} | 售${p.sales}', style: AppTextStyles.bodySmall),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textHint),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
