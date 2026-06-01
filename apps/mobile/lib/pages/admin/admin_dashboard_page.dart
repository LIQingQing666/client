import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

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

  // 切换选择模式
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  // 切换单个商品选中状态
  void _toggleProductSelection(String productId) {
    setState(() {
      if (_selectedIds.contains(productId)) {
        _selectedIds.remove(productId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(productId);
      }
    });
  }

  // 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _products.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_products.map((p) => p.id));
      }
    });
  }

  // 删除选中商品
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 件商品吗？'),
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

    // 显示加载
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
            Text('正在删除...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);

      // 逐个删除选中的商品
      int successCount = 0;
      int failCount = 0;

      for (final id in _selectedIds.toList()) {
        try {
          await api.deleteProduct(id);
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('删除商品 $id 失败: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (failCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('成功删除 $successCount 件商品'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('成功删除 $successCount 件，失败 $failCount 件'),
              backgroundColor: AppColors.warning,
            ),
          );
        }

        _loadProducts(); // 重新加载列表
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _buildActionBar(context),
            Expanded(
              child: _buildProductList(context),
            ),
          ],
        ),
        if (_isSelectionMode && _selectedIds.isNotEmpty)
          _buildBottomDeleteBar(),
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
          if (_isSelectionMode) ...[
            // select mode
            GestureDetector(
              onTap: _toggleSelectAll,
              child: Text(
                _selectedIds.length == _products.length ? '取消全选' : '全选',
                style: AppTextStyles.bodyMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '已选 ${_selectedIds.length} 件',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(width: AppDimens.paddingMd),
            GestureDetector(
              onTap: _toggleSelectionMode,
              child: const Text(
                '取消',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ] else ...[
            // check mode
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
                  _loadProducts();
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
        ],
      ),
    );
  }


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
    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.paddingLg,
          0,
          AppDimens.paddingLg,
          AppDimens.paddingLg,
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final p = _products[index];
          final isSelected = _selectedIds.contains(p.id);
          final isLastItem = index == _products.length - 1;

          return _ProductCard(
            product: p,
            isSelectionMode: _isSelectionMode,
            isSelected: isSelected,
            isLastItem: isLastItem,
            hasSelectionBar: _isSelectionMode && _selectedIds.isNotEmpty,
            onTap: () {
              if (_isSelectionMode) {
                _toggleProductSelection(p.id);
              } else {
                _navigateToDetail(p.id);
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedIds.add(p.id);
                });
                HapticFeedback.mediumImpact();
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _navigateToDetail(String productId) async {
    final result = await context.pushNamed<bool>(
      'adminProductDetail',
      pathParameters: {'id': productId},
    );

    // 如果详情页返回 true（商品被删除），立即刷新列表
    if (result == true) {
      _loadProducts();
    }
  }

  Widget _buildBottomDeleteBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        width: MediaQuery.of(context).size.width,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + AppDimens.paddingMd,
          top: AppDimens.paddingMd,
          left: AppDimens.paddingLg,
          right: AppDimens.paddingLg,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              label: Text(
                '删除选中 (${_selectedIds.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                disabledBackgroundColor: AppColors.error.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 商品卡片组件
final class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isSelectionMode,
    required this.isSelected,
    required this.isLastItem,
    required this.hasSelectionBar,
    required this.onTap,
    required this.onLongPress,
  });

  final ProductModel product;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isLastItem;
  final bool hasSelectionBar;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(
          bottom: isLastItem && hasSelectionBar ? 80 : AppDimens.paddingSm,
        ),
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: isSelected
              ? Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          )
              : null,
        ),
        child: Row(
          children: [
            // 左侧：始终显示商品图片
            _buildProductImage(),
            const SizedBox(width: AppDimens.paddingMd),
            // 中间：商品信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '¥${product.price.toStringAsFixed(0)} | 库存${product.stock} | 售${product.sales}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.paddingSm),
            // 右侧：选择模式显示勾选框，普通模式显示分类标签
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: isSelectionMode
                  ? _buildCheckbox()
                  : _buildCategoryTag(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Image.network(
        product.coverUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 48,
          height: 48,
          color: AppColors.divider,
          child: const Icon(
            Icons.image,
            size: 24,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.textHint.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }

  Widget _buildCategoryTag() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingSm,
        vertical: AppDimens.paddingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Text(
        product.category,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
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
