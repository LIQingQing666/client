import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import '../utils/toast.dart';
import 'service_providers.dart';

enum FavoriteType { video, product }

final class FavoriteItem {
  const FavoriteItem({
    required this.id,
    required this.type,
    required this.title,
    required this.coverUrl,
    required this.subtitle,
    this.rawData = const {},
  });

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String?) ?? 'video';
    return FavoriteItem(
      id: json['id'] as String,
      type: typeStr == 'product' ? FavoriteType.product : FavoriteType.video,
      title: (json['title'] as String?) ?? '',
      coverUrl: (json['cover_url'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      rawData: (json['raw_data'] as Map<String, dynamic>?) ?? {},
    );
  }

  final String id;
  final FavoriteType type;
  final String title;
  final String coverUrl;
  final String subtitle;
  final Map<String, dynamic> rawData;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == FavoriteType.product ? 'product' : 'video',
        'title': title,
        'cover_url': coverUrl,
        'subtitle': subtitle,
        'raw_data': rawData,
      };

  bool get isVideo => type == FavoriteType.video;
  bool get isProduct => type == FavoriteType.product;
}

final class FavoriteState {
  const FavoriteState({this.items = const []});

  final List<FavoriteItem> items;

  List<FavoriteItem> get videos =>
      items.where((i) => i.isVideo).toList();
  List<FavoriteItem> get products =>
      items.where((i) => i.isProduct).toList();

  bool isFavorited(String id) => items.any((i) => i.id == id);

  FavoriteState copyWith({List<FavoriteItem>? items}) =>
      FavoriteState(items: items ?? this.items);
}

final class FavoriteNotifier extends StateNotifier<FavoriteState> {
  FavoriteNotifier({required this.storage}) : super(const FavoriteState()) {
    _loadFromStorage();
  }

  final StorageService storage;

  void _loadFromStorage() {
    final raw = storage.getFavorites();
    if (raw.isNotEmpty) {
      state = FavoriteState(
        items: raw.map((e) => FavoriteItem.fromJson(e)).toList(),
      );
    }
  }

  Future<void> _persist() async {
    await storage.saveFavorites(
      state.items.map((e) => e.toJson()).toList(),
    );
  }

  bool isFavorited(String id) => state.isFavorited(id);

  void toggleVideoFavorite({
    required String id,
    required String title,
    required String coverUrl,
    required String authorName,
    String authorId = '',
    String authorAvatar = '',
  }) {
    final existing = state.items.indexWhere((i) => i.id == id && i.isVideo);
    if (existing >= 0) {
      final updated = [...state.items]..removeAt(existing);
      state = state.copyWith(items: updated);
      showFavoriteToast('已取消收藏');
    } else {
      final item = FavoriteItem(
        id: id,
        type: FavoriteType.video,
        title: title,
        coverUrl: coverUrl,
        subtitle: authorName,
        rawData: {
          if (authorId.isNotEmpty) 'author_id': authorId,
          if (authorAvatar.isNotEmpty) 'author_avatar': authorAvatar,
        },
      );
      state = state.copyWith(items: [item, ...state.items]);
      showFavoriteToast('已收藏');
    }
    _persist();
  }

  void toggleProductFavorite({
    required String id,
    required String name,
    required String coverUrl,
    required double price,
    String videoId = '',
    int highlightTime = 0,
  }) {
    final existing = state.items.indexWhere((i) => i.id == id && i.isProduct);
    if (existing >= 0) {
      final updated = [...state.items]..removeAt(existing);
      state = state.copyWith(items: updated);
      showFavoriteToast('已取消收藏');
    } else {
      final item = FavoriteItem(
        id: id,
        type: FavoriteType.product,
        title: name,
        coverUrl: coverUrl,
        subtitle: '¥${price.toStringAsFixed(0)}',
        rawData: {
          if (videoId.isNotEmpty) 'video_id': videoId,
          if (highlightTime > 0) 'highlight_time': highlightTime,
        },
      );
      state = state.copyWith(items: [item, ...state.items]);
      showFavoriteToast('已收藏');
    }
    _persist();
  }

  void removeFavorite(String id) {
    final updated = [...state.items]..removeWhere((i) => i.id == id);
    state = state.copyWith(items: updated);
    _persist();
    showToast('已取消收藏');
  }
}

final favoriteProvider =
    StateNotifierProvider<FavoriteNotifier, FavoriteState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return FavoriteNotifier(storage: storage);
});