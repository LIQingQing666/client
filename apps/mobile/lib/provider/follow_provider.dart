import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';
import '../services/storage_service.dart';
import '../utils/toast.dart';
import 'service_providers.dart';

final class FollowState {
  const FollowState({this.followingIds = const <String>{}, this.isLoading = false});

  final Set<String> followingIds;
  final bool isLoading;

  FollowState copyWith({Set<String>? followingIds, bool? isLoading}) {
    return FollowState(
      followingIds: followingIds ?? this.followingIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final class FollowNotifier extends StateNotifier<FollowState> {
  FollowNotifier({required this.client, required this.storage}) : super(const FollowState());

  final DioClient client;
  final StorageService storage;

  String get _userId => storage.userId ?? 'u1';

  Future<void> loadFollowing() async {
    try {
      final response = await client.get<Map<String, dynamic>>('/users/$_userId/following');
      final data = response.data!['data'] as Map<String, dynamic>;
      final list = (data['following'] as List<dynamic>?) ?? [];
      final ids = list.map((e) => (e as Map<String, dynamic>)['id'].toString()).toSet();
      state = state.copyWith(followingIds: ids);
    } on Exception {
      // silent fail - we'll try on individual actions
    }
  }

  Future<bool> toggleFollow(String targetUserId) async {
    final isFollowing = state.followingIds.contains(targetUserId);
    try {
      if (isFollowing) {
        await client.delete<Map<String, dynamic>>('/users/$targetUserId/follow', data: {'user_id': _userId});
        state = state.copyWith(followingIds: {...state.followingIds}..remove(targetUserId));
        return false;
      } else {
        await client.post<Map<String, dynamic>>('/users/$targetUserId/follow', data: {'user_id': _userId});
        state = state.copyWith(followingIds: {...state.followingIds, targetUserId});
        return true;
      }
    } on Exception {
      showToast(isFollowing ? '取消关注失败' : '关注失败');
      rethrow;
    }
  }

  bool isFollowing(String userId) => state.followingIds.contains(userId);
}

final followProvider = StateNotifierProvider<FollowNotifier, FollowState>((ref) {
  final client = ref.watch(dioClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return FollowNotifier(client: client, storage: storage);
});
