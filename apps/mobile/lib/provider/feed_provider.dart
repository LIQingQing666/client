import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/video_api.dart';
import '../core/app_constants.dart';
import '../models/video_model.dart';
import '../services/player_pool.dart';
import '../services/storage_service.dart';
import '../services/video_preload_manager.dart';
import '../utils/toast.dart';
import 'service_providers.dart';

final videoApiProvider = Provider<VideoApi>((ref) {
  return VideoApi(client: ref.watch(dioClientProvider));
});

enum FeedTab { recommend, follow }

final class FeedState {
  const FeedState({
    this.videos = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.tab = FeedTab.recommend,
    this.errorMessage,
  });

  final List<VideoModel> videos;
  final int currentIndex;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final FeedTab tab;
  final String? errorMessage;

  FeedState copyWith({
    List<VideoModel>? videos,
    int? currentIndex,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    FeedTab? tab,
    String? errorMessage,
  }) {
    return FeedState(
      videos: videos ?? this.videos,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      tab: tab ?? this.tab,
      errorMessage: errorMessage,
    );
  }
}

final class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier({required this.api, required this.pool, required this.storage, required this.preloadManager})
      : super(const FeedState()) {
    loadVideos();
  }

  final VideoApi api;
  final PlayerPool pool;
  final StorageService storage;
  final VideoPreloadManager preloadManager;

  String get _userId => storage.userId ?? 'u1';

  Future<void> loadVideos() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, page: 1, errorMessage: null);
    final isRecommend = state.tab == FeedTab.recommend;

    try {
      final response = isRecommend
          ? await api.getRecommend()
          : await api.getFollow(userId: _userId);
      state = state.copyWith(
        videos: response.list,
        isLoading: false,
        hasMore: response.hasMore,
      );
      _preloadAround(0);
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      showToast('加载失败，请检查网络');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.page + 1;
    final isRecommend = state.tab == FeedTab.recommend;

    try {
      final response = isRecommend
          ? await api.getRecommend(page: nextPage)
          : await api.getFollow(userId: _userId, page: nextPage);

      state = state.copyWith(
        videos: [...state.videos, ...response.list],
        isLoadingMore: false,
        hasMore: response.hasMore,
        page: nextPage,
      );
    } on Exception catch (e) {
      state = state.copyWith(isLoadingMore: false, errorMessage: e.toString());
      showToast('加载更多失败');
    }
  }

  Future<void> switchTab(FeedTab tab) async {
    if (state.tab == tab || state.isLoading) return;
    state = state.copyWith(tab: tab, videos: [], currentIndex: 0);
    await loadVideos();
  }

  void setCurrentIndex(int index) {
    if (index == state.currentIndex) {
      return;
    }
    state = state.copyWith(currentIndex: index);
    _preloadAround(index);

    // Load more when near the end
    if (index >= state.videos.length - 3 && state.hasMore) {
      loadMore();
    }
  }

  Future<void> toggleLike(String videoId) async {
    try {
      final liked = await api.toggleLike(videoId, _userId);
      final updated = state.videos.map((v) {
        if (v.id != videoId) {
          return v;
        }
        return VideoModel(
          id: v.id,
          title: v.title,
          description: v.description,
          coverUrl: v.coverUrl,
          videoUrl: v.videoUrl,
          authorId: v.authorId,
          authorName: v.authorName,
          authorAvatar: v.authorAvatar,
          duration: v.duration,
          tags: v.tags,
          likeCount: liked ? v.likeCount + 1 : v.likeCount - 1,
          commentCount: v.commentCount,
          shareCount: v.shareCount,
          playCount: v.playCount,
          createdAt: v.createdAt,
          isLiked: liked,
        );
      }).toList();

      state = state.copyWith(videos: updated);
    }
    on Exception {
      showToast('操作失败');
    }
  }

  void _preloadAround(int index) {
    final videos = state.videos;
    if (videos.isEmpty) {
      return;
    }

    // Cancel previous preloads that are no longer relevant.
    _cancelStalePreloads(index);

    // Preload next N videos (default: preloadVideoCount).
    final count = AppConstants.preloadVideoCount;
    for (int i = 1; i <= count; i++) {
      final nextIndex = index + i;
      if (nextIndex < videos.length) {
        final v = videos[nextIndex];
        preloadManager.enqueue(v.id, v.videoUrl, priority: count - i);
      }
    }
  }

  void _cancelStalePreloads(int currentIndex) {
    final videos = state.videos;
    final keepRange = currentIndex + AppConstants.preloadVideoCount;
    for (int i = 0; i < videos.length; i++) {
      if (i < currentIndex || i > keepRange) {
        preloadManager.cancel(videos[i].id);
      }
    }
  }
}

final muteStateProvider = StateProvider<bool>((ref) => false);

final feedProvider =
    StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  final api = ref.watch(videoApiProvider);
  final pool = ref.watch(playerPoolProvider);
  final storage = ref.watch(storageServiceProvider);
  final preloadManager = ref.watch(videoPreloadManagerProvider);
  return FeedNotifier(api: api, pool: pool, storage: storage, preloadManager: preloadManager);
});
