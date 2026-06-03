import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/live_api.dart';
import '../../core/app_constants.dart';
import '../../models/live_model.dart';
import '../../models/product_model.dart';
import '../../provider/service_providers.dart';

final class LiveRoomPage extends ConsumerStatefulWidget {
  const LiveRoomPage({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<LiveRoomPage> createState() => _LiveRoomPageState();
}

final class _LiveRoomPageState extends ConsumerState<LiveRoomPage> {
  LiveRoomInfo? _room;
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoomDetail();
  }

  Future<void> _loadRoomDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = LiveApi(client: ref.read(dioClientProvider));
      final detail = await api.getRoomDetail(widget.roomId);
      if (mounted) {
        setState(() {
          _room = detail.room;
          _products = detail.products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reserveLive() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已预约「${_room?.title ?? ''}」，开播时会通知你'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _room == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.white54),
              const SizedBox(height: 16),
              Text(_error ?? '加载失败', style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    final room = _room!;
    final isLive = room.isLive;
    final isPreview = room.isPreview;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(room.title, style: const TextStyle(color: Colors.white)),
        actions: [
          if (isLive)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('直播中', style: TextStyle(color: Colors.white, fontSize: 12)),
            )
          else if (isPreview)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('预告', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (isLive)
            _buildLiveContent()
          else if (isPreview)
            _buildPreviewContent()
          else
            _buildEndedContent(),

          // 底部商品条
          if (_products.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: _buildProductStrip(),
            ),
        ],
      ),
    );
  }

  /// 直播中内容
  Widget _buildLiveContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 封面（模拟视频）
        CachedNetworkImage(
          imageUrl: _room!.coverUrl,
          fit: BoxFit.cover,
        ),
        // 遮罩
        Container(color: Colors.black.withValues(alpha: 0.3)),
        // 直播提示
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.error, width: 3),
                ),
                child: const Icon(Icons.play_arrow, color: AppColors.error, size: 40),
              ),
              const SizedBox(height: 16),
              const Text('直播进行中', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                '${_room!.onlineCountText} 人观看',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 预告内容
  Widget _buildPreviewContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: _room!.coverUrl,
          fit: BoxFit.cover,
        ),
        Container(color: Colors.black.withValues(alpha: 0.4)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.notifications_active, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                '直播即将开始',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(_room!.title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 32),
              SizedBox(
                width: 200, height: 48,
                child: ElevatedButton(
                  onPressed: _reserveLive,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('预约直播', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 已结束内容
  Widget _buildEndedContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          const Text('直播已结束', style: TextStyle(color: Colors.white54, fontSize: 18)),
          const SizedBox(height: 8),
          Text(_room!.title, style: const TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }

  /// 商品条
  Widget _buildProductStrip() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final product = _products[index];
          return GestureDetector(
            onTap: () {
              // 点击查看商品
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: product.coverUrl,
                    width: 44, height: 44, fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1),
                    Text('¥${product.price.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
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
