import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import 'service_providers.dart';

final class UserState {
  const UserState({this.nickname, this.avatar, this.coinBalance = 0});

  final String? nickname;
  final String? avatar;
  final double coinBalance;

  UserState copyWith({String? nickname, String? avatar, double? coinBalance}) {
    return UserState(
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      coinBalance: coinBalance ?? this.coinBalance,
    );
  }
}

final class UserNotifier extends StateNotifier<UserState> {
  UserNotifier({required this.storage}) : super(const UserState()) {
    _init();
  }

  final StorageService storage;

  void _init() {
    final profile = storage.getUserProfile();
    if (profile != null) {
      state = UserState(
        nickname: profile['nickname'] as String?,
        avatar: profile['avatar'] as String?,
      );
    }
  }

  Future<void> updateProfile({String? nickname, String? avatar}) async {
    final current = storage.getUserProfile() ?? <String, dynamic>{};
    if (nickname != null) current['nickname'] = nickname;
    if (avatar != null) current['avatar'] = avatar;
    await storage.setUserProfile(current);
    state = state.copyWith(nickname: nickname, avatar: avatar);
  }

  void refresh() {
    final profile = storage.getUserProfile();
    if (profile != null) {
      state = UserState(
        nickname: profile['nickname'] as String?,
        avatar: profile['avatar'] as String?,
        coinBalance: (profile['coin_balance'] as num?)?.toDouble() ?? 0,
      );
    }
  }

  void updateCoinBalance(double balance) {
    state = state.copyWith(coinBalance: balance);
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return UserNotifier(storage: storage);
});
