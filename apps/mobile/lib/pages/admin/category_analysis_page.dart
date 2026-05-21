import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/admin_api.dart';
import '../../core/app_constants.dart';
import '../../provider/service_providers.dart';

final class CategoryAnalysisPage extends ConsumerStatefulWidget {
  const CategoryAnalysisPage({super.key});

  @override
  ConsumerState<CategoryAnalysisPage> createState() => _CategoryAnalysisPageState();
}

final class _CategoryAnalysisPageState extends ConsumerState<CategoryAnalysisPage> {
  List<CategoryStat> _list = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = ref.read(dioClientProvider);
      final api = AdminApi(client: client);
      final data = await api.getDashboard();
      if (mounted) {
        setState(() {
          _list = data.categories;
          _isLoading = false;
        });
      }
    } on Exception {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxSales = _list.isEmpty
        ? 1
        : _list.map((e) => e.totalSales).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('品类分析')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _list.isEmpty
              ? const Center(child: Text('暂无数据', style: AppTextStyles.bodyMedium))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppDimens.paddingLg),
                  itemCount: _list.length,
                  itemBuilder: (context, index) {
                    final stat = _list[index];
                    final ratio = maxSales > 0 ? stat.totalSales / maxSales : 0.0;

                    final colors = [
                      const Color(0xFFE8453C),
                      const Color(0xFFFF6B35),
                      const Color(0xFFFF9800),
                      const Color(0xFF4CAF50),
                      const Color(0xFF4A90D9),
                      const Color(0xFF7B61FF),
                    ];
                    final color = colors[index % colors.length];

                    return Container(
                      margin: const EdgeInsets.only(bottom: AppDimens.paddingMd),
                      padding: const EdgeInsets.all(AppDimens.paddingMd),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(stat.category, style: AppTextStyles.bodyLarge),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${stat.count}件商品',
                                      style: AppTextStyles.bodySmall),
                                  Text('售${stat.totalSales}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      )),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.paddingSm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: AppColors.divider,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
