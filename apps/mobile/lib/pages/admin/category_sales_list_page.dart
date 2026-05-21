import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/product_api.dart';
import '../../core/app_constants.dart';
import '../../models/product_model.dart';
import '../../provider/service_providers.dart';

final class CategorySalesListPage extends ConsumerStatefulWidget {
  const CategorySalesListPage({super.key, required this.category});

  final String category;

  @override
  ConsumerState<CategorySalesListPage> createState() => _CategorySalesListPageState();
}

final class _CategorySalesListPageState extends ConsumerState<CategorySalesListPage> {
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
        final filtered = result.list
            .where((p) => p.category == widget.category)
            .toList()
          ..sort((a, b) => b.sales.compareTo(a.sales));
        setState(() {
          _products = filtered;
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
      appBar: AppBar(title: Text('${widget.category} - 销售排行')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _products.isEmpty
              ? const Center(child: Text('暂无数据', style: AppTextStyles.bodyMedium))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppDimens.paddingLg),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    final rank = index + 1;
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
                            SizedBox(
                              width: 24,
                              child: Text(
                                '$rank',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: rank <= 3 ? AppColors.primary : AppColors.textHint,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimens.paddingSm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                              child: CachedNetworkImage(
                                imageUrl: p.coverUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(width: 44, height: 44, color: AppColors.divider),
                              ),
                            ),
                            const SizedBox(width: AppDimens.paddingMd),
                            Expanded(
                              child: Text(p.name, style: AppTextStyles.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            Text('售${p.sales}', style: AppTextStyles.priceSmall),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
