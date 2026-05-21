import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/admin_api.dart';
import '../../core/app_constants.dart';
import '../../provider/service_providers.dart';

final class GmvRankingPage extends ConsumerStatefulWidget {
  const GmvRankingPage({super.key});

  @override
  ConsumerState<GmvRankingPage> createState() => _GmvRankingPageState();
}

final class _GmvRankingPageState extends ConsumerState<GmvRankingPage> {
  List<VideoGmvItem> _list = [];
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
          _list = data.videoGmv;
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
      appBar: AppBar(title: const Text('视频 GMV 排行')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _list.isEmpty
              ? const Center(child: Text('暂无数据', style: AppTextStyles.bodyMedium))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppDimens.paddingLg),
                  itemCount: _list.length,
                  itemBuilder: (context, index) {
                    final item = _list[index];
                    final rank = index + 1;
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppDimens.paddingSm),
                      padding: const EdgeInsets.all(AppDimens.paddingMd),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '$rank',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: rank <= 3 ? AppColors.primary : AppColors.textHint,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: AppDimens.paddingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title,
                                    style: AppTextStyles.bodyLarge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(item.authorName, style: AppTextStyles.bodySmall),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppDimens.paddingMd),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('¥${item.gmv.toStringAsFixed(0)}',
                                  style: AppTextStyles.priceSmall),
                              Text('播放${item.playCount} | 售${item.productSales}',
                                  style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
