// lib/pages/live/live_broadcast_page.dart

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/live_api.dart';
import '../../core/app_constants.dart';
import '../../models/live_model.dart';
import '../../models/product_model.dart';
import '../../provider/service_providers.dart';

final class LiveBroadcastPage extends ConsumerStatefulWidget {
  const LiveBroadcastPage({super.key, required this.room});

  final LiveRoomInfo room;  // ✅ 使用 LiveRoomInfo

  @override
  ConsumerState<LiveBroadcastPage> createState() => _LiveBroadcastPageState();
}

final class _LiveBroadcastPageState extends ConsumerState<LiveBroadcastPage> {
  late LiveRoomInfo _room;  // ✅ 使用 LiveRoomInfo
  Timer? _viewerTimer;
  Timer? _likeTimer;

  List<ProductModel> _products = [];
  ProductModel? _currentProduct;

  int _viewerCount = 0;
  int _likeCount = 0;
  final List<LiveMessage> _messages = [];  // ✅ 从 live_model.dart 导入

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _viewerCount = _room.onlineCount;
    _likeCount = _room.likeCount;
    _startSimulation();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final api = LiveApi(client: ref.read(dioClientProvider));
      final detail = await api.getRoomDetail(_room.id);
      if (mounted) {
        setState(() => _products = detail.products);
      }
    } catch (e) {
      debugPrint('加载商品失败: $e');
    }
  }

  void _startSimulation() {
    _viewerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _viewerCount = (_viewerCount + (1 + (DateTime.now().millisecond % 5))).clamp(0, 9999);
        });
      }
    });

    _likeTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() => _likeCount += (1 + (DateTime.now().millisecond % 10)));
        if (DateTime.now().millisecond % 3 == 0) _addSimulatedMessage();
      }
    });
  }

  void _addSimulatedMessage() {
    final names = ['观众A', '粉丝B', '路人C', '买家D', '新粉E'];
    final contents = ['这个多少钱？', '好看！', '已下单', '支持主播', '质量怎么样？', '有优惠吗？'];
    _messages.insert(0, LiveMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userName: names[DateTime.now().millisecond % names.length],
      content: contents[DateTime.now().millisecond % contents.length],
      type: 'user',
    ));
    if (_messages.length > 50) _messages.removeRange(50, _messages.length);
  }

  Future<void> _switchProduct(ProductModel product) async {
    try {
      final api = LiveApi(client: ref.read(dioClientProvider));
      // ✅ 使用命名参数
      await api.switchProduct(roomId: _room.id, productId: product.id);
      setState(() => _currentProduct = product);
      _messages.insert(0, LiveMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userName: '系统',
        content: '主播正在讲解：${product.name}',
        type: 'system',
        productId: product.id,
      ));
    } catch (e) {
      debugPrint('切换商品失败: $e');
    }
  }

  Future<void> _endLive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束直播'),
        content: const Text('确定要结束直播吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('继续直播')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('结束')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final api = LiveApi(client: ref.read(dioClientProvider));
        await api.endLive(_room.id);
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('结束失败: $e')));
      }
    }
  }

  @override
  void dispose() {
    _viewerTimer?.cancel();
    _likeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 模拟直播画面
          Container(
            color: const Color(0xFF1A1A2E),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 3)),
                    child: const Icon(Icons.videocam, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text('模拟直播画面', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      // ✅ 修复 const 错误
                      SizedBox(
                        width: 8, height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text('直播中', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // 当前商品卡片
          if (_currentProduct != null)
            Positioned(top: 60, left: 12, right: 120, child: _buildProductCard(_currentProduct!)),

          // 右侧商品列表
          Positioned(top: 60, right: 8, bottom: 80, width: 100, child: _buildProductList()),

          // 聊天消息
          Positioned(left: 8, bottom: 130, width: 200, height: 200, child: _buildChatList()),

          // 底部信息栏
          Positioned(bottom: 80, left: 0, right: 0, child: _buildInfoBar()),

          // 底部控制栏
          Positioned(bottom: 0, left: 0, right: 0, child: _buildControlBar()),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(6), child: CachedNetworkImage(imageUrl: product.coverUrl, width: 50, height: 50, fit: BoxFit.cover)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1),
          const SizedBox(height: 4),
          Text('¥${product.price.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 16)),
        ])),
      ]),
    );
  }

  Widget _buildProductList() {
    return ListView.separated(
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final product = _products[index];
        final isActive = _currentProduct?.id == product.id;
        return GestureDetector(
          onTap: () => _switchProduct(product),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isActive ? AppColors.primary : Colors.white24, width: isActive ? 2 : 1),
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(6), child: CachedNetworkImage(imageUrl: product.coverUrl, width: 90, height: 90, fit: BoxFit.cover)),
          ),
        );
      },
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      reverse: true,
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
          child: RichText(
            text: TextSpan(children: [
              TextSpan(text: '${msg.userName}: ', style: const TextStyle(color: Colors.yellow, fontSize: 11, fontWeight: FontWeight.w500)),
              TextSpan(text: msg.content, style: const TextStyle(color: Colors.white, fontSize: 11)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black87,
      child: Row(children: [
        _buildStat(Icons.visibility, '$_viewerCount'),
        const SizedBox(width: 16),
        _buildStat(Icons.favorite, '$_likeCount', color: Colors.red),
        const Spacer(),
        Text(_room.title, style: const TextStyle(color: Colors.white)),
      ]),
    );
  }

  Widget _buildStat(IconData icon, String count, {Color? color}) {
    return Row(children: [
      Icon(icon, color: color ?? Colors.white, size: 16),
      const SizedBox(width: 4),
      Text(count, style: TextStyle(color: color ?? Colors.white, fontSize: 13)),
    ]);
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
      child: SafeArea(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _buildCtrlBtn(Icons.chat, '评论'),
          _buildCtrlBtn(Icons.share, '分享'),
          _buildCtrlBtn(Icons.shopping_bag, '商品'),
          _buildCtrlBtn(Icons.favorite_border, '点赞', onTap: () => setState(() => _likeCount++)),
          GestureDetector(
            onTap: _endLive,
            child: Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error),
              child: const Center(child: Text('结束', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCtrlBtn(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 26),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ]),
    );
  }
}
