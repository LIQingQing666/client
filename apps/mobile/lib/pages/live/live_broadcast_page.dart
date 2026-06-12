import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../api/live_api.dart';
import '../../core/app_constants.dart';
import '../../models/live_model.dart';
import '../../models/product_model.dart';
import '../../provider/service_providers.dart';
import '../../provider/live_provider.dart';

final class LiveBroadcastPage extends ConsumerStatefulWidget {
  const LiveBroadcastPage({super.key, required this.room});

  final LiveRoomInfo room;

  @override
  ConsumerState<LiveBroadcastPage> createState() => _LiveBroadcastPageState();
}

final class _LiveBroadcastPageState extends ConsumerState<LiveBroadcastPage> {
  late LiveRoomInfo _room;
  Timer? _viewerTimer;
  Timer? _likeTimer;

  List<ProductModel> _products = [];
  ProductModel? _currentProduct;

  int _viewerCount = 0;
  int _likeCount = 0;

  VideoPlayerController? _videoController;
  bool _isVideoReady = false;
  bool _hasVideoError = false;
  String? _errorMessage;

  String _aiLiveScript = '';
  bool _isGeneratingScript = false;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _viewerCount = _room.onlineCount;
    _likeCount = _room.likeCount;
    _startSimulation();
    _loadProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initVideoPlayer();
      ref.read(liveProvider.notifier).enterRoom(_room.id);
    });
  }

  List<LiveMessage> get _messages => ref.watch(liveProvider).messages;

  int get _realtimeOnlineCount => ref.watch(liveProvider).onlineCount;

  int get _realtimeLikeCount => ref.watch(liveProvider).likeCount;

  String get _heatCountText => ref.watch(liveProvider).heatCountText;

  bool get _isConnected => ref.watch(liveProvider).isConnected;

  // 初始化视频播放器
  Future<void> _initVideoPlayer() async {
    final videoUrl = _room.videoUrl;

    if (videoUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasVideoError = true;
          _errorMessage = '视频地址为空\n请确认创建直播间时设置了视频地址';
        });
      }
      return;
    }

    try {
      _videoController = VideoPlayerController.network(
        videoUrl,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await _videoController!.initialize();
      if (mounted) {
        setState(() {
          _isVideoReady = true;
          _hasVideoError = false;
        });
        _videoController!.play();
        _videoController!.setLooping(true);
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _hasVideoError = true;
          _errorMessage = '视频加载失败\n请检查视频地址是否有效';
        });
      }
    }
  }

  // 重新加载视频
  Future<void> _reloadVideo() async {
    setState(() {
      _isVideoReady = false;
      _hasVideoError = false;
      _errorMessage = null;
    });

    _videoController?.dispose();
    _videoController = null;

    // 重新获取房间详情以更新视频URL
    try {
      final api = LiveApi(client: ref.read(dioClientProvider));
      final detail = await api.getRoomDetail(_room.id);

      if (mounted) {
        // 👇 通过 detail.room 访问 LiveRoomInfo
        final updatedRoom = detail.room;
        setState(() {
          _room = updatedRoom;
        });
      }
    } catch (e) {
    }

    // 重新初始化播放器
    _initVideoPlayer();
  }

  Future<void> _loadProducts() async {
    try {
      final api = LiveApi(client: ref.read(dioClientProvider));
      final detail = await api.getRoomDetail(_room.id);
      if (mounted) {
        setState(() {
          _products = detail.products;

          final roomInfo = detail.room;

          if (detail.products.isNotEmpty) {
            final currentId = roomInfo.currentProductId;

            if (currentId != null && currentId.isNotEmpty) {
              try {
                _currentProduct = detail.products.firstWhere(
                      (p) => p.id == currentId,
                );
              } catch (e) {
                _currentProduct = detail.products.first;
              }
            } else {
              _currentProduct = detail.products.first;
            }

            // 生成初始 AI 文案
            if (_currentProduct != null) {
              _generateAiLiveScript(_currentProduct!);
            }
          }
        });
      }
    } catch (e, stackTrace) {
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
    final userName = names[DateTime.now().millisecond % names.length];
    final content = contents[DateTime.now().millisecond % contents.length];
    // Use the notifier's simulateMessage which properly creates a new
    // immutable state — instead of mutating the list in place via ref.watch.
    ref.read(liveProvider.notifier).simulateMessage(userName, content);
  }

  Future<void> _switchProduct(ProductModel product) async {
    try {
      final api = LiveApi(client: ref.read(dioClientProvider));
      await api.switchProduct(roomId: _room.id, productId: product.id);
      setState(() => _currentProduct = product);
      ref.read(liveProvider.notifier).sendMessage('主播正在讲解：${product.name}');

      // 生成 AI 直播文案
      _generateAiLiveScript(product);
    } catch (e) {
      debugPrint('切换商品失败: $e');
    }
  }

  Future<void> _generateAiLiveScript(ProductModel product) async {
    setState(() {
      _isGeneratingScript = true;
      _aiLiveScript = '正在生成讲解文案...';
    });

    try {
      final client = ref.read(dioClientProvider);
      final api = LiveApi(client: client);

      final script = await api.generateAiLiveScript(
        roomTitle: _room.title,
        productName: product.name,
        productDescription: product.description ?? '',
        productCategory: product.category,
        productTags: product.tags?.cast<String>(),
      );

      if (mounted) {
        setState(() {
          _aiLiveScript = script;
          _isGeneratingScript = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiLiveScript = '${product.name}，品质之选，限时优惠中！';
          _isGeneratingScript = false;
        });
      }
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

        ref.read(liveProvider.notifier).leaveRoom();

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('结束失败: $e'))
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _viewerTimer?.cancel();
    _likeTimer?.cancel();
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    try {
      ref.read(liveProvider.notifier).leaveRoom();
    } catch (_) {
      // widget 已销毁，忽略
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveProvider);

    return WillPopScope(
      onWillPop: () async {
        await _endLive();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _buildVideoPlayer(),

            if (_isConnected)
              Positioned(
                top: MediaQuery.of(context).padding.top + 40,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '已连接',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),

            if (_currentProduct != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 50,
                left: 12,
                right: 120,
                child: _buildProductCard(_currentProduct!),
              ),

            Positioned(
              top: MediaQuery.of(context).padding.top + 50,
              right: 8,
              bottom: 200,
              width: 100,
              child: _buildProductList(),
            ),

            Positioned(
              left: 8,
              bottom: 180,
              width: 250,
              height: 220,
              child: _CommentList(messages: state.messages),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_hasVideoError) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? '视频加载失败',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _reloadVideo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新加载'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isVideoReady) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '视频加载中...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Live broadcast — should play continuously, no pause tap.
    return Stack(
        fit: StackFit.expand,
        children: [
          // 视频播放器
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),

          // 直播标签
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 8,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '直播中',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
    );
  }

  // 商品卡片
  Widget _buildProductCard(ProductModel product) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: product.coverUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 50,
                height: 50,
                color: AppColors.divider,
                child: const Icon(Icons.image, color: AppColors.textHint),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    if (_products.isEmpty) {
      return const Center(
        child: Text(
          '暂无商品',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return ListView.separated(
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final product = _products[index];
        final isActive = _currentProduct?.id == product.id;
        return GestureDetector(
          onTap: () => _switchProduct(product),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? AppColors.primary : Colors.white24,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: product.coverUrl,
                    width: 90,
                    height: 70,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 90,
                      height: 70,
                      color: AppColors.divider,
                      child: const Icon(Icons.image, color: AppColors.textHint),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatList() {
    if (_messages.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            '暂无消息',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isSystem = msg.type == 'system';
        final isProduct = msg.type == 'product';
        final isGift = msg.type == 'gift';

        Color bgColor;
        if (isSystem) {
          bgColor = Colors.orange.withValues(alpha: 0.3);
        } else if (isProduct) {
          bgColor = AppColors.primary.withValues(alpha: 0.3);
        } else if (isGift) {
          bgColor = Colors.pink.withValues(alpha: 0.3);
        } else {
          bgColor = Colors.black54;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: RichText(
            text: TextSpan(
              children: [
                if (!isSystem && !isGift)
                  TextSpan(
                    text: '${msg.userName}: ',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                TextSpan(
                  text: msg.content,
                  style: TextStyle(
                    color: (isSystem || isGift) ? Colors.orange : Colors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 底部栏
  Widget _buildBottomBar() {
    final state = ref.watch(liveProvider);
    final displayViewerCount = _isConnected ? state.onlineCount : _viewerCount;
    final displayLikeCount = _isConnected ? state.likeCount : _likeCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87, Colors.black],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 统计数据和AI文案行
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧：统计数据
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatItem(
                      icon: Icons.visibility,
                      label: '观众',
                      count: _formatCount(displayViewerCount),
                    ),
                    const SizedBox(height: 6),
                    _buildStatItem(
                      icon: Icons.favorite,
                      label: '点赞',
                      count: _formatCount(displayLikeCount),
                      color: Colors.red,
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                // 右侧：AI 文案（用 Expanded 撑满剩余空间 + ConstrainedBox 限高）
                Expanded(
                  child: SizedBox(
                    height: 100,
                    child: _AiScriptCard(
                      script: _aiLiveScript,
                      isGenerating: _isGeneratingScript,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 结束按钮
            Center(
              child: GestureDetector(
                onTap: _endLive,
                child: Container(
                  width: 80,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '结束',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String count,
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color ?? Colors.white,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          count,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return count.toString();
  }
}

final class _CommentList extends StatelessWidget {
  const _CommentList({required this.messages});

  final List<LiveMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          '暂无消息',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    final displayMessages = messages.length > 20
        ? messages.sublist(messages.length - 20)
        : messages;

    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.zero,
      itemCount: displayMessages.length,
      itemBuilder: (context, index) {
        final msg = displayMessages[index];
        final isSystem = msg.isSystem || msg.type == 'gift';

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSystem
                ? Colors.orange.withValues(alpha: 0.3)
                : Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          child: RichText(
            text: TextSpan(
              children: [
                if (!isSystem)
                  TextSpan(
                    text: '${msg.userName}: ',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                TextSpan(
                  text: msg.content,
                  style: TextStyle(
                    color: isSystem ? Colors.orange : Colors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ========== AI 文案卡片（独立 Widget，避免上下文约束问题） ==========
final class _AiScriptCard extends StatelessWidget {
  const _AiScriptCard({
    required this.script,
    required this.isGenerating,
  });

  final String script;
  final bool isGenerating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 13,
                ),
              ),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  'AI 讲解文案',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isGenerating) ...[
                const SizedBox(width: 6),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                script.isEmpty ? '选择商品后自动生成讲解文案' : script,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: script.isEmpty ? 0.4 : 0.9,
                  ),
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _AiIcon extends StatelessWidget {
  const _AiIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 13,
      ),
    );
  }
}
