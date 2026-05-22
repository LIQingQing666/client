import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/live_api.dart';
import '../../core/app_constants.dart';
import '../../models/live_model.dart';
import '../../provider/service_providers.dart';

final class LivePage extends ConsumerStatefulWidget {
  const LivePage({super.key});

  @override
  ConsumerState<LivePage> createState() => _LivePageState();
}

final class _LivePageState extends ConsumerState<LivePage> {
  final _pageController = PageController();
  List<LiveRoomInfo> _rooms = [];
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 0;

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

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = LiveApi(client: ref.read(dioClientProvider));
      final rooms = await api.getRooms();
      if (!mounted) return;
      ref.read(roomListProvider.notifier).state = rooms;
      setState(() {
        _rooms = rooms;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.textHint),
              const SizedBox(height: AppDimens.paddingMd),
              const Text('加载失败', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppDimens.paddingLg),
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

    if (_rooms.isEmpty) {
      return Scaffold(
        body: Center(child: Text('暂无直播', style: AppTextStyles.titleMedium)),
      );
    }

    return Scaffold(
      body: Stack(
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
          // Top info
          Positioned(
            top: MediaQuery.of(context).padding.top + AppDimens.paddingSm,
            left: AppDimens.paddingLg,
            right: AppDimens.paddingLg,
            child: Row(
              children: [
                Text(
                  '直播',
                  style: AppTextStyles.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
                  onPressed: _loadRooms,
                ),
              ],
            ),
          ),

          // Page indicator
          Positioned(
            right: AppDimens.paddingMd,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _rooms.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final isActive = idx == _currentIndex;
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
      ),
    );
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
        // Cover image
        CachedNetworkImage(
          imageUrl: room.coverUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: AppColors.card),
          errorWidget: (context, url, error) => Container(color: AppColors.card),
        ),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withAlpha(200),
              ],
            ),
          ),
        ),
        // Live badge
        Positioned(
          top: MediaQuery.of(context).padding.top + 50,
          left: AppDimens.paddingLg,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingSm, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
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
        // Bottom info
        Positioned(
          left: AppDimens.paddingLg,
          right: AppDimens.paddingLg,
          bottom: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(room.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 2),
              const SizedBox(height: AppDimens.paddingSm),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.card,
                    child: Text(room.authorName.isNotEmpty ? room.authorName[0] : '?', style: const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                  const SizedBox(width: AppDimens.paddingSm),
                  Text(room.authorName, style: const TextStyle(fontSize: 14, color: Colors.white)),
                  const SizedBox(width: AppDimens.paddingMd),
                  const Icon(Icons.person, color: Colors.white70, size: 14),
                  Text(' ${room.onlineCountText}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
        // Enter button
        Positioned(
          left: AppDimens.paddingLg,
          right: AppDimens.paddingLg,
          bottom: 50,
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
              ),
              child: const Text('进入直播间', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}
