// lib/pages/live/live_page.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/live_api.dart';
import '../../core/app_constants.dart';
import '../../models/live_model.dart';
import '../../provider/service_providers.dart';
import 'create_live_page.dart';
import 'live_broadcast_page.dart';

final class LivePage extends ConsumerStatefulWidget {
  const LivePage({super.key});

  @override
  ConsumerState<LivePage> createState() => _LivePageState();
}

final class _LivePageState extends ConsumerState<LivePage> {
  final _pageController = PageController();

  // 直播列表
  List<LiveRoomInfo> _rooms = [];
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 0;

  // 商家面板
  bool _showCreatorPanel = false;
  List<LiveRoomInfo> _myRooms = [];
  bool _isLoadingMyRooms = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isMerchant {
    final storage = ref.read(storageServiceProvider);
    final role = storage.role;
    return role == 'merchant' || role == 'admin';
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = LiveApi(client: ref.read(dioClientProvider));
      final rooms = await api.getRooms();
      if (!mounted) return;
      setState(() {
        _rooms = rooms.where((r) => r.isLive).toList();
        _isLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMyRooms() async {
    if (!_isMerchant) return;

    setState(() => _isLoadingMyRooms = true);
    try {
      final api = LiveApi(client: ref.read(dioClientProvider));
      final rooms = await api.getMyRooms();
      if (mounted) {
        setState(() {
          _myRooms = rooms;
          _isLoadingMyRooms = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMyRooms = false);
      debugPrint('加载我的直播间失败: $e');
    }
  }

  void _toggleCreatorPanel() {
    if (!_isMerchant) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('仅商家账号可以使用此功能'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _showCreatorPanel = !_showCreatorPanel;
    });
    if (_showCreatorPanel && _myRooms.isEmpty) {
      _loadMyRooms();
    }
  }

  Future<void> _navigateToCreateLive() async {
    if (!_isMerchant) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateLivePage()),
    );
    if (result == true) {
      _loadMyRooms();
      _loadRooms();
    }
  }

  Future<void> _startLive(LiveRoomInfo room) async {
    try {
      final api = LiveApi(client: ref.read(dioClientProvider));
      await api.startLive(room.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('直播已开始'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveBroadcastPage(
              room: room.copyWith(status: 'live'),
            ),
          ),
        ).then((_) {
          _loadMyRooms();
          _loadRooms();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('开始失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _enterBroadcastPage(LiveRoomInfo room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveBroadcastPage(room: room),
      ),
    ).then((_) {
      _loadMyRooms();
      _loadRooms();
    });
  }

  // ========== UI 构建 ==========

  @override
  Widget build(BuildContext context) {
    // 加载中
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // 加载失败
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadRooms,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    // 无直播
    if (_rooms.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('暂无直播', style: TextStyle(color: Colors.white70, fontSize: 18)),
                  const SizedBox(height: 12),
                  Text(
                    '← 左滑开启你的直播',
                    style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 14),
                  ),
                ],
              ),
            ),
            // 顶部栏
            _buildTopBar(),
            // 右滑提示
            if (_isMerchant) _buildSwipeHint(),
            // 创作者面板
            if (_showCreatorPanel)
              Positioned(
                right: 0, top: 0, bottom: 0,
                width: MediaQuery.of(context).size.width * 0.75,
                child: _buildCreatorPanel(),
              ),
          ],
        ),
      );
    }

    // 有直播 - 主界面
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onHorizontalDragEnd: _isMerchant ? (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            if (!_showCreatorPanel) _toggleCreatorPanel();
          } else if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
            if (_showCreatorPanel) _toggleCreatorPanel();
          }
        } : null,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Transform.translate(
                offset: Offset(
                  _showCreatorPanel ? -MediaQuery.of(context).size.width * 0.75 : 0,
                  0,
                ),
                child: _buildMainContent(),
              ),
            ),
            if (_showCreatorPanel)
              Positioned(
                right: 0, top: 0, bottom: 0,
                width: MediaQuery.of(context).size.width * 0.75,
                child: _buildCreatorPanel(),
              ),
          ],
        ),
      ),
    );
  }

  /// 顶部栏
  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Row(
        children: [
          if (_isMerchant)
            GestureDetector(
              onTap: _toggleCreatorPanel,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_forward_ios, color: Colors.white.withAlpha(180), size: 12),
                    const SizedBox(width: 4),
                    Text('我的', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 80),
          const Spacer(),
          const Text('直播', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRooms,
          ),
        ],
      ),
    );
  }

  /// 右滑提示条
  Widget _buildSwipeHint() {
    return Positioned(
      left: 0, top: 0, bottom: 0,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
            _toggleCreatorPanel();
          }
        },
        child: Container(
          width: 30,
          color: Colors.transparent,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(Icons.chevron_left, color: Colors.white.withAlpha(80), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 主内容区
  Widget _buildMainContent() {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: _rooms.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            final room = _rooms[index];
            return _LiveRoomFullCard(
              room: room,
              onTap: () {
                context.pushNamed('liveRoom', pathParameters: {'roomId': room.id});
              },
            );
          },
        ),

        _buildTopBar(),

        if (_isMerchant) _buildSwipeHint(),

        // 页面指示器
        if (_rooms.length > 1)
          Positioned(
            right: 12, top: 0, bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _rooms.asMap().entries.map((entry) {
                  final isActive = entry.key == _currentIndex;
                  return Container(
                    width: 3,
                    height: isActive ? 20 : 12,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : Colors.white.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  /// 创作者面板
  Widget _buildCreatorPanel() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: SafeArea(
        child: Column(
          children: [
            // 头部
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _toggleCreatorPanel,
                    child: const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '我的直播',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  // 开播按钮
                  GestureDetector(
                    onTap: _navigateToCreateLive,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8453C), Color(0xFFFF6B35)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('开播', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12),

            // 内容区
            Expanded(
              child: _isLoadingMyRooms
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _myRooms.isEmpty
                  ? _buildEmptyCreatorView()
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _myRooms.length,
                itemBuilder: (context, index) => _buildMyRoomCard(_myRooms[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 空的创作者视图
  Widget _buildEmptyCreatorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.primary.withValues(alpha: 0.1)],
              ),
            ),
            child: const Icon(Icons.live_tv, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('当前没有正在进行的直播', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('点击右上角"开播"创建直播间', style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _navigateToCreateLive,
            icon: const Icon(Icons.add),
            label: const Text('创建直播间'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ),
    );
  }

  /// 我的直播间卡片
  Widget _buildMyRoomCard(LiveRoomInfo room) {
    if (!room.isLive) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _enterBroadcastPage(room);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: room.coverUrl,
                    width: 60, height: 80, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 60, height: 80, color: AppColors.divider,
                      child: const Icon(Icons.image, color: AppColors.textHint),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.title,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '直播中',
                          style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${room.productIds.length}件商品 · ${room.onlineCountText}观看',
                        style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reserveLive(LiveRoomInfo room) async {
    // 直接显示 SnackBar，不调用 API
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已预约「${room.title}」，开播时会通知你'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

final class _LiveRoomFullCard extends StatelessWidget {
  const _LiveRoomFullCard({required this.room, this.onTap});

  final LiveRoomInfo room;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: room.coverUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: AppColors.card),
          errorWidget: (_, __, ___) => Container(color: AppColors.card),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withAlpha(200)],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 50,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, color: Colors.white, size: 14),
                Text('直播中', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        // 底部信息
        Positioned(
          left: 16, right: 16, bottom: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(room.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 2),
              const SizedBox(height: 8),
              Row(children: [
                CircleAvatar(
                  radius: 14, backgroundColor: AppColors.card,
                  child: Text(room.authorName.isNotEmpty ? room.authorName[0] : '?', style: const TextStyle(fontSize: 10, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Text(room.authorName, style: const TextStyle(fontSize: 14, color: Colors.white)),
                const SizedBox(width: 16),
                const Icon(Icons.person, color: Colors.white70, size: 14),
                Text(' ${room.onlineCountText}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ]),
            ],
          ),
        ),
        Positioned(
          left: 16, right: 16, bottom: 50,
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('进入直播间', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}
