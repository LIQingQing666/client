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
import 'add_video_page.dart';
import 'edit_video_page.dart';

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

// lib/pages/admin/admin_dashboard_page.dart

final class _ProductManagementTabState
    extends ConsumerState<_ProductManagementTab> {
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _error;

  // 多选相关状态
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // 过滤状态
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isSelectionMode = false;
      _selectedIds.clear();
    });
    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);
      final result = await api.getProducts(page: 1, pageSize: 50, status: 'all');
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

  // 过滤后的商品列表
  List<ProductModel> get _filteredProducts {
    switch (_statusFilter) {
      case 'active':
        return _products.where((p) => p.isActive).toList();
      case 'inactive':
        return _products.where((p) => !p.isActive).toList();
      default:
        return _products;
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
      if (_selectedIds.length == _filteredProducts.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_filteredProducts.map((p) => p.id));
      }
    });
  }

  // 获取选中商品中上架和下架的数量
  int get _selectedActiveCount {
    return _selectedIds
        .where((id) => _products.any((p) => p.id == id && p.isActive))
        .length;
  }

  int get _selectedInactiveCount {
    return _selectedIds
        .where((id) => _products.any((p) => p.id == id && !p.isActive))
        .length;
  }

  // 下架选中商品
  Future<void> _deactivateSelected() async {
    if (_selectedIds.isEmpty) return;

    final activeIds = _selectedIds
        .where((id) => _products.any((p) => p.id == id && p.isActive))
        .toList();

    if (activeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选中的商品已是下架状态')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认下架'),
        content: Text('确定要下架选中的 ${activeIds.length} 件商品吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('下架'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    _showLoadingSnackBar('正在下架...');

    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);

      int successCount = 0;
      int failCount = 0;

      for (final id in activeIds) {
        try {
          await api.deactivateProduct(id);
          // 更新本地状态
          final index = _products.indexWhere((p) => p.id == id);
          if (index != -1) {
            _products[index] = _products[index].copyWith(status: 'inactive');
          }
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('下架商品 $id 失败: $e');
        }
      }

      if (mounted) {
        _hideLoadingSnackBar();

        if (failCount == 0) {
          _showSuccessSnackBar('成功下架 $successCount 件商品');
        } else {
          _showWarningSnackBar('成功下架 $successCount 件，失败 $failCount 件');
        }

        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _hideLoadingSnackBar();
        _showErrorSnackBar('下架失败: $e');
      }
    }
  }

  // 上架选中商品
  Future<void> _activateSelected() async {
    if (_selectedIds.isEmpty) return;

    final inactiveIds = _selectedIds
        .where((id) => _products.any((p) => p.id == id && !p.isActive))
        .toList();

    if (inactiveIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选中的商品已是上架状态')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认上架'),
        content: Text('确定要上架选中的 ${inactiveIds.length} 件商品吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: const Text('上架'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    _showLoadingSnackBar('正在上架...');

    try {
      final client = ref.read(dioClientProvider);
      final api = ProductApi(client: client);

      int successCount = 0;
      int failCount = 0;

      for (final id in inactiveIds) {
        try {
          await api.activateProduct(id);
          // 更新本地状态
          final index = _products.indexWhere((p) => p.id == id);
          if (index != -1) {
            _products[index] = _products[index].copyWith(status: 'active');
          }
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('上架商品 $id 失败: $e');
        }
      }

      if (mounted) {
        _hideLoadingSnackBar();

        if (failCount == 0) {
          _showSuccessSnackBar('成功上架 $successCount 件商品');
        } else {
          _showWarningSnackBar('成功上架 $successCount 件，失败 $failCount 件');
        }

        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _hideLoadingSnackBar();
        _showErrorSnackBar('上架失败: $e');
      }
    }
  }

  // 根据当前过滤页面执行对应操作
  Future<void> _handleBatchAction() async {
    if (_statusFilter == 'inactive') {
      // 在已下架页面，执行上架操作
      await _activateSelected();
    } else {
      // 在全部或已上架页面，执行下架操作
      await _deactivateSelected();
    }
  }

  // ========== SnackBar 辅助方法 ==========

  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );
  }

  void _hideLoadingSnackBar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // 顶部操作栏
            _buildActionBar(context),
            // 状态过滤栏
            _buildFilterBar(),
            // 商品列表
            Expanded(
              child: _buildProductList(context),
            ),
          ],
        ),
        // 底部操作按钮
        if (_isSelectionMode && _selectedIds.isNotEmpty)
          _buildBottomActionBar(),
      ],
    );
  }

  Widget _buildFilterBar() {
    final activeCount = _products.where((p) => p.isActive).length;
    final inactiveCount = _products.where((p) => !p.isActive).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.paddingLg,
        AppDimens.paddingSm,
        AppDimens.paddingLg,
        AppDimens.paddingSm,
      ),
      child: Row(
        children: [
          _buildFilterChip('全部', 'all', _products.length),
          const SizedBox(width: 8),
          _buildFilterChip('已上架', 'active', activeCount),
          const SizedBox(width: 8),
          _buildFilterChip('已下架', 'inactive', inactiveCount),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _statusFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = value;
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.divider,
            width: 1,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? AppColors.primary : AppColors.textHint,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.paddingLg,
        AppDimens.paddingMd,
        AppDimens.paddingLg,
        0,
      ),
      child: Row(
        children: [
          if (_isSelectionMode) ...[
            GestureDetector(
              onTap: _toggleSelectAll,
              child: Text(
                _selectedIds.length == _filteredProducts.length ? '取消全选' : '全选',
                style: const TextStyle(color: AppColors.primary),
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
            Expanded(
              child: Text(
                '共 ${_filteredProducts.length} 件商品',
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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
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
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final displayProducts = _filteredProducts;

    if (displayProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _statusFilter == 'inactive' ? Icons.publish : Icons.inventory_2,
              size: 64,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppDimens.paddingMd),
            Text(
              _statusFilter == 'active'
                  ? '暂无上架商品'
                  : _statusFilter == 'inactive'
                  ? '暂无下架商品'
                  : '暂无商品',
              style: AppTextStyles.bodyMedium,
            ),
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
        itemCount: displayProducts.length,
        itemBuilder: (context, index) {
          final p = displayProducts[index];
          final isSelected = _selectedIds.contains(p.id);
          final isLastItem = index == displayProducts.length - 1;

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

    if (result == true) {
      _loadProducts();
    }
  }

  Widget _buildBottomActionBar() {
    final isInactiveTab = _statusFilter == 'inactive';
    final activeCount = _selectedActiveCount;
    final inactiveCount = _selectedInactiveCount;

    // 决定按钮文字和操作
    String buttonText;
    int count;
    VoidCallback? onPressed;
    Color buttonColor;
    IconData buttonIcon;

    if (isInactiveTab) {
      // 在已下架页面，显示上架按钮
      buttonText = '上架选中';
      count = inactiveCount;
      onPressed = inactiveCount > 0 ? _activateSelected : null;
      buttonColor = AppColors.success;
      buttonIcon = Icons.arrow_upward;
    } else {
      // 在全部或已上架页面，显示下架按钮
      buttonText = '下架选中';
      count = activeCount;
      onPressed = activeCount > 0 ? _deactivateSelected : null;
      buttonColor = AppColors.warning;
      buttonIcon = Icons.arrow_downward;
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 12,
          top: 12,
          left: 16,
          right: 16,
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
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(buttonIcon, color: Colors.white),
            label: Text(
              count > 0 ? '$buttonText ($count)' : '无需操作',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              disabledBackgroundColor: AppColors.textHint.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
              : product.status == 'inactive'
              ? AppColors.card.withValues(alpha: 0.6)
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
            // 左侧：商品图片
            _buildProductImage(),
            const SizedBox(width: AppDimens.paddingMd),
            // 中间：商品信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.bodyMedium?.copyWith(
                      color: product.status == 'inactive'
                          ? AppColors.textHint
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '¥${product.price.toStringAsFixed(0)} | 库存${product.stock} | 售${product.sales}',
                    style: AppTextStyles.bodySmall?.copyWith(
                      color: product.status == 'inactive'
                          ? AppColors.textHint
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.paddingSm),
            // 右侧：选择模式显示勾选框，普通模式显示状态标签
            if (isSelectionMode)
              _buildCheckbox()
            else
              _buildStatusTag(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    return Opacity(
      opacity: product.status == 'inactive' ? 0.5 : 1.0,
      child: ClipRRect(
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

  Widget _buildStatusTag() {
    final isActive = product.status == 'active';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.textHint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.textHint.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppColors.success : AppColors.textHint,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? '已上架' : '已下架',
            style: TextStyle(
              fontSize: 11,
              color: isActive ? AppColors.success : AppColors.textHint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  // 多选相关状态
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // 过滤状态
  String _statusFilter = 'all'; // 'all', 'draft', 'published', 'inactive'

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isSelectionMode = false;
      _selectedIds.clear();
    });
    try {
      final client = ref.read(dioClientProvider);
      final api = VideoApi(client: client);
      final result = await api.getVideos(page: 1, pageSize: 1000, status: 'all');
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

  // 过滤后的视频列表
  List<VideoModel> get _filteredVideos {
    switch (_statusFilter) {
      case 'draft':
        return _videos.where((v) => v.isDraft).toList();
      case 'published':
        return _videos.where((v) => v.isPublished).toList();
      case 'inactive':
        return _videos.where((v) => v.isInactive).toList();
      default:
        return _videos;
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleVideoSelection(String videoId) {
    setState(() {
      if (_selectedIds.contains(videoId)) {
        _selectedIds.remove(videoId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(videoId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _filteredVideos.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_filteredVideos.map((v) => v.id));
      }
    });
  }

  int _getSelectedCountByStatus(String status) {
    return _selectedIds
        .where((id) => _videos.any((v) => v.id == id && v.status == status))
        .length;
  }

  // 批量发布
  Future<void> _publishSelected() async {
    final draftIds = _selectedIds
        .where((id) => _videos.any((v) => v.id == id && v.isDraft))
        .toList();

    if (draftIds.isEmpty) {
      _showSnackBar('选中的视频没有草稿状态');
      return;
    }

    await _batchUpdateStatus(draftIds, 'published', '发布');
  }

  // 批量下架
  Future<void> _deactivateSelected() async {
    final publishedIds = _selectedIds
        .where((id) => _videos.any((v) => v.id == id && v.isPublished))
        .toList();

    if (publishedIds.isEmpty) {
      _showSnackBar('选中的视频没有已发布状态');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认下架'),
        content: Text('确定要下架选中的 ${publishedIds.length} 个视频吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('下架'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _batchUpdateStatus(publishedIds, 'inactive', '下架');
    }
  }

  // 批量上架
  Future<void> _reactivateSelected() async {
    final inactiveIds = _selectedIds
        .where((id) => _videos.any((v) => v.id == id && v.isInactive))
        .toList();

    if (inactiveIds.isEmpty) {
      _showSnackBar('选中的视频没有已下架状态');
      return;
    }

    await _batchUpdateStatus(inactiveIds, 'published', '上架');
  }

  // 批量更新状态
  Future<void> _batchUpdateStatus(
      List<String> ids,
      String newStatus,
      String actionName,
      ) async {
    if (!mounted) return;

    _showLoadingSnackBar('正在$actionName...');

    try {
      final client = ref.read(dioClientProvider);
      final api = VideoApi(client: client);

      int successCount = 0;
      int failCount = 0;

      for (final id in ids) {
        try {
          await api.updateVideoStatus(id, newStatus);
          // 更新本地状态
          final index = _videos.indexWhere((v) => v.id == id);
          if (index != -1) {
            _videos[index] = _copyVideoWithStatus(_videos[index], newStatus);
          }
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('$actionName视频 $id 失败: $e');
        }
      }

      if (mounted) {
        _hideLoadingSnackBar();

        if (failCount == 0) {
          _showSuccessSnackBar('成功$actionName $successCount 个视频');
        } else {
          _showWarningSnackBar('成功$actionName $successCount 个，失败 $failCount 个');
        }

        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _hideLoadingSnackBar();
        _showErrorSnackBar('$actionName失败: $e');
      }
    }
  }

  // 辅助：创建状态变更后的 VideoModel 副本
  VideoModel _copyVideoWithStatus(VideoModel video, String newStatus) {
    return VideoModel(
      id: video.id,
      title: video.title,
      description: video.description,
      coverUrl: video.coverUrl,
      videoUrl: video.videoUrl,
      authorId: video.authorId,
      authorName: video.authorName,
      authorAvatar: video.authorAvatar,
      duration: video.duration,
      tags: video.tags,
      likeCount: video.likeCount,
      commentCount: video.commentCount,
      shareCount: video.shareCount,
      playCount: video.playCount,
      createdAt: video.createdAt,
      isLiked: video.isLiked,
      status: newStatus,
    );
  }

  // ========== SnackBar 辅助方法 ==========

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );
  }

  void _hideLoadingSnackBar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ========== 导航 ==========

  Future<void> _navigateToDetail(String videoId) async {
    final result = await context.pushNamed<bool>(
      'adminVideoDetail',
      pathParameters: {'id': videoId},
    );

    if (result == true) {
      _loadVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _buildActionBar(context),
            _buildFilterBar(),
            Expanded(
              child: _buildVideoList(context),
            ),
          ],
        ),
        if (_isSelectionMode && _selectedIds.isNotEmpty)
          _buildBottomActionBar(),
      ],
    );
  }

  // ========== UI 组件 ==========

  Widget _buildFilterBar() {
    final draftCount = _videos.where((v) => v.isDraft).length;
    final publishedCount = _videos.where((v) => v.isPublished).length;
    final inactiveCount = _videos.where((v) => v.isInactive).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.paddingLg, AppDimens.paddingSm,
        AppDimens.paddingLg, AppDimens.paddingSm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('全部', 'all', _videos.length),
            const SizedBox(width: 8),
            _buildFilterChip('草稿', 'draft', draftCount),
            const SizedBox(width: 8),
            _buildFilterChip('已发布', 'published', publishedCount),
            const SizedBox(width: 8),
            _buildFilterChip('已下架', 'inactive', inactiveCount),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _statusFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = value;
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: 1,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? AppColors.primary : AppColors.textHint,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.paddingLg, AppDimens.paddingMd,
        AppDimens.paddingLg, 0,
      ),
      child: Row(
        children: [
          if (_isSelectionMode) ...[
            GestureDetector(
              onTap: _toggleSelectAll,
              child: Text(
                _selectedIds.length == _filteredVideos.length ? '取消全选' : '全选',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
            const Spacer(),
            Text('已选 ${_selectedIds.length} 个', style: AppTextStyles.bodyMedium),
            const SizedBox(width: AppDimens.paddingMd),
            GestureDetector(
              onTap: _toggleSelectionMode,
              child: const Text('取消', style: TextStyle(color: AppColors.primary)),
            ),
          ] else ...[
            Expanded(
              child: Text('共 ${_filteredVideos.length} 个视频', style: AppTextStyles.bodySmall),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddVideoPage()),
                );
                if (result == true) _loadVideos();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加视频'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.paddingMd, vertical: AppDimens.paddingSm),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoList(BuildContext context) {
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

    final displayVideos = _filteredVideos;

    if (displayVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _statusFilter == 'draft' ? Icons.edit_note :
              _statusFilter == 'inactive' ? Icons.videocam_off : Icons.videocam,
              size: 64,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppDimens.paddingMd),
            Text(
              _statusFilter == 'draft' ? '暂无草稿' :
              _statusFilter == 'published' ? '暂无已发布视频' :
              _statusFilter == 'inactive' ? '暂无下架视频' : '暂无视频',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.paddingLg, 0,
          AppDimens.paddingLg, AppDimens.paddingLg,
        ),
        itemCount: displayVideos.length,
        itemBuilder: (context, index) {
          final v = displayVideos[index];
          final isSelected = _selectedIds.contains(v.id);

          return _VideoCard(
            video: v,
            isSelectionMode: _isSelectionMode,
            isSelected: isSelected,
            onTap: () {
              if (_isSelectionMode) {
                _toggleVideoSelection(v.id);
              } else {
                _navigateToDetail(v.id);
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedIds.add(v.id);
                });
                HapticFeedback.mediumImpact();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final draftCount = _getSelectedCountByStatus('draft');
    final publishedCount = _getSelectedCountByStatus('published');
    final inactiveCount = _getSelectedCountByStatus('inactive');

    List<Widget> actions = [];

    if (draftCount > 0) {
      actions.add(_buildActionButton(
        icon: Icons.publish, label: '发布($draftCount)',
        color: AppColors.success, onPressed: _publishSelected,
      ));
    }
    if (publishedCount > 0) {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
      actions.add(_buildActionButton(
        icon: Icons.arrow_downward, label: '下架($publishedCount)',
        color: AppColors.warning, onPressed: _deactivateSelected,
      ));
    }
    if (inactiveCount > 0) {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
      actions.add(_buildActionButton(
        icon: Icons.publish, label: '上架($inactiveCount)',
        color: AppColors.primary, onPressed: _reactivateSelected,
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 12,
          top: 12, left: 16, right: 16,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8, offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(children: actions),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 18),
          label: Text(label, style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

final class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final VideoModel video;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimens.paddingSm),
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: isSelected
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              child: Image.network(
                video.coverUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: AppColors.divider,
                  child: const Icon(Icons.videocam, size: 24, color: AppColors.textHint),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.paddingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${video.authorName} | 播放${video.playCountText} | 赞${video.likeCountText}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.paddingSm),
            if (isSelectionMode)
              _buildCheckbox()
            else
              _buildStatusTag(),
          ],
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

  Widget _buildStatusTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: video.statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: video.statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(
              shape: BoxShape.circle, color: video.statusColor)),
          const SizedBox(width: 6),
          Text(video.statusText, style: TextStyle(
              fontSize: 11, color: video.statusColor, fontWeight: FontWeight.w600)),
        ],
      ),
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
