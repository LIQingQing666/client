import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/admin_api.dart';
import '../../api/product_api.dart';
import '../../api/video_api.dart';
import '../../core/app_constants.dart';
import '../../models/product_model.dart';
import '../../models/video_model.dart';
import '../../provider/admin_provider.dart';
import '../../provider/service_providers.dart';
import 'add_product_page.dart';

final class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

final class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('商家后台'),
        backgroundColor: AppColors.background,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          tabs: const [
            Tab(text: '数据看板'),
            Tab(text: '商品管理'),
            Tab(text: '视频管理'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final idx = _tabController.index;
              if (idx == 0) ref.read(adminProvider.notifier).loadDashboard();
              if (idx == 1 || idx == 2) setState(() {});
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _DashboardTab(),
          const _ProductManagementTab(),
          const _VideoManagementTab(),
        ],
      ),
    );
  }
}

// ---- Dashboard Tab (existing content) ----

final class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppDimens.paddingMd),
            Text(state.errorMessage!, style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }
    if (state.data == null) {
      return const Center(child: Text('暂无数据'));
    }
    final data = state.data!;
    return ListView(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      children: [
        _SummaryCard(gmv: data.totalGmv),
        const SizedBox(height: AppDimens.paddingLg),
        const _SectionTitle(title: '转化漏斗'),
        const SizedBox(height: AppDimens.paddingSm),
        _FunnelChart(funnel: data.funnel),
        const SizedBox(height: AppDimens.paddingLg),
        const _SectionTitle(title: '热门商品 Top 10'),
        const SizedBox(height: AppDimens.paddingSm),
        ...data.topProducts.map((p) => _TopProductRow(
          product: p,
          onTap: () => context.pushNamed('adminProductDetail', pathParameters: {'id': p.id}),
        )),
        const SizedBox(height: AppDimens.paddingLg),
        GestureDetector(
          onTap: () => context.pushNamed('gmvRanking'),
          child: const _SectionTitle(title: '视频 GMV 排行'),
        ),
        const SizedBox(height: AppDimens.paddingSm),
        ...data.videoGmv.map((v) => _VideoGmvRow(
          item: v,
          onTap: () => context.pushNamed('playVideo', pathParameters: {'videoId': v.id}),
        )),
        const SizedBox(height: AppDimens.paddingLg),
        GestureDetector(
          onTap: () => context.pushNamed('categoryAnalysis'),
          child: const _SectionTitle(title: '品类分布'),
        ),
        const SizedBox(height: AppDimens.paddingSm),
        ...data.categories.map((c) => _CategoryRow(
          stat: c,
          onProductTap: () => context.pushNamed('categoryProducts',
            pathParameters: {'category': c.category},
          ),
          onSalesTap: () => context.pushNamed('categorySales',
            pathParameters: {'category': c.category},
          ),
        )),
      ],
    );
  }
}

// ---- Product Management Tab ----

final class _ProductManagementTab extends ConsumerStatefulWidget {
  const _ProductManagementTab();

  @override
  ConsumerState<_ProductManagementTab> createState() =>
      _ProductManagementTabState();
}

final class _ProductManagementTabState
    extends ConsumerState<_ProductManagementTab> {
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);
      final result = await api.getProducts(page: 1, pageSize: 50);
      setState(() {
        _products = result.list;
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
    return Column(
      children: [
        // 顶部操作栏
        _buildActionBar(context),
        // 商品列表
        Expanded(
          child: _buildProductList(context),
        ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.paddingLg,
        AppDimens.paddingMd,
        AppDimens.paddingLg,
        AppDimens.paddingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '共 ${_products.length} 件商品',
              style: AppTextStyles.bodySmall,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddProductPage(),
                ),
              );
              if (result == true) {
                _loadProducts(); // 刷新列表
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加商品'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.paddingMd,
                vertical: AppDimens.paddingSm,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget _buildProductList(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppDimens.paddingMd),
            Text(_error!, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppDimens.paddingMd),
            ElevatedButton(onPressed: _loadProducts, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: AppDimens.paddingMd),
            const Text('暂无商品', style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppDimens.paddingSm),
            const Text('点击上方按钮添加第一个商品', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final p = _products[index];
        return _ManagementCard(
          imageUrl: p.coverUrl,
          title: p.name,
          subtitle: '¥${p.price.toStringAsFixed(0)} | 库存${p.stock} | 售${p.sales}',
          tag: p.category,
          tagColor: AppColors.primary,
          onTap: () => context.pushNamed('adminProductDetail', pathParameters: {'id': p.id}),
        );
      },
    );
  }
}

// ---- Video Management Tab ----

final class _VideoManagementTab extends ConsumerStatefulWidget {
  const _VideoManagementTab();

  @override
  ConsumerState<_VideoManagementTab> createState() =>
      _VideoManagementTabState();
}

final class _VideoManagementTabState
    extends ConsumerState<_VideoManagementTab> {
  List<VideoModel> _videos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = ref.read(dioClientProvider);
      final api = VideoApi(client: client);
      final result = await api.getVideos(page: 1);
      setState(() {
        _videos = result.list;
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppDimens.paddingMd),
            Text(_error!, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppDimens.paddingMd),
            ElevatedButton(onPressed: _loadVideos, child: const Text('重试')),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final v = _videos[index];
        return _ManagementCard(
          imageUrl: v.coverUrl,
          title: v.title,
          subtitle: '${v.authorName} | 播放${v.playCount} | 赞${v.likeCount}',
          tag: '播放中',
          tagColor: AppColors.success,
          onTap: () => context.pushNamed('adminVideoDetail', pathParameters: {'id': v.id}),
        );
      },
    );
  }
}

// ---- Shared management card ----

final class _ManagementCard extends StatelessWidget {
  const _ManagementCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
    this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final String tag;
  final Color tagColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            child: Image.network(
              imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(width: 48, height: 48, color: AppColors.divider),
            ),
          ),
          const SizedBox(width: AppDimens.paddingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.paddingSm,
              vertical: AppDimens.paddingXs,
            ),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 11,
                color: tagColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ---- Shared widgets (from original page) ----

final class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.gmv});

  final double gmv;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8453C), Color(0xFFFF6B35)],
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        children: [
          const Text('累计 GMV',
              style: TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: AppDimens.paddingXs),
          Text(
            '¥${gmv.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

final class _FunnelChart extends StatelessWidget {
  const _FunnelChart({required this.funnel});

  final FunnelData funnel;

  @override
  Widget build(BuildContext context) {
    final items = [
      _FunnelItem(
          label: '视频曝光',
          value: funnel.impressions,
          color: const Color(0xFF4A90D9)),
      _FunnelItem(
          label: '商品点击',
          value: funnel.productClicks,
          rate: funnel.rates.clickThrough,
          color: const Color(0xFF7B61FF)),
      _FunnelItem(
          label: '加入购物车',
          value: funnel.addToCart,
          rate: funnel.rates.cartConversion,
          color: const Color(0xFFFF9800)),
      _FunnelItem(
          label: '下单支付',
          value: funnel.orders,
          rate: funnel.rates.orderConversion,
          color: const Color(0xFF4CAF50)),
    ];
    final maxValue =
        items.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        children: items.map((item) {
          final ratio = maxValue > 0 ? item.value / maxValue : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.paddingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.label, style: AppTextStyles.bodyMedium),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.value.toString(), style: AppTextStyles.bodyLarge),
                        if (item.rate != null) ...[
                          const SizedBox(width: AppDimens.paddingSm),
                          Text('${item.rate!.toStringAsFixed(1)}%',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: item.color,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(item.color),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

final class _FunnelItem {
  const _FunnelItem({
    required this.label,
    required this.value,
    this.rate,
    required this.color,
  });

  final String label;
  final int value;
  final double? rate;
  final Color color;
}

final class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.product, this.onTap});

  final TopProduct product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: AppDimens.paddingSm),
      padding: const EdgeInsets.all(AppDimens.paddingSm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: Image.network(
              product.coverUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(width: 40, height: 40, color: AppColors.card),
            ),
          ),
          const SizedBox(width: AppDimens.paddingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(product.category, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('¥${product.price.toStringAsFixed(0)}',
                  style: AppTextStyles.priceSmall),
              Text('销量 ${product.sales}', style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    ));
  }
}

final class _VideoGmvRow extends StatelessWidget {
  const _VideoGmvRow({required this.item, this.onTap});

  final VideoGmvItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: AppDimens.paddingSm),
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.authorName, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
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
    ),
    );
  }
}

final class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.stat, this.onProductTap, this.onSalesTap});

  final CategoryStat stat;
  final VoidCallback? onProductTap;
  final VoidCallback? onSalesTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.paddingSm),
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(stat.category, style: AppTextStyles.bodyMedium),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onProductTap,
                child: Text('${stat.count}件商品',
                    style: AppTextStyles.bodySmall),
              ),
              const Text(' | ', style: AppTextStyles.bodySmall),
              GestureDetector(
                onTap: onSalesTap,
                child: Text('售${stat.totalSales}',
                    style: AppTextStyles.bodySmall),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.titleMedium);
  }
}
