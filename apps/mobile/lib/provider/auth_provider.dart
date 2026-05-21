import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import 'service_providers.dart';

final class AuthState {
  const AuthState({this.isLoggedIn = false, this.userId, this.role});

  final bool isLoggedIn;
  final String? userId;
  final String? role;

  AuthState copyWith({bool? isLoggedIn, String? userId, String? role}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: userId ?? this.userId,
      role: role ?? this.role,
    );
  }
}

final class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({required this.storage}) : super(const AuthState()) {
    _init();
  }

  final StorageService storage;

  void _init() {
    final token = storage.token;
    if (token != null && token.isNotEmpty) {
      final auth = AuthState(
        isLoggedIn: true,
        userId: storage.userId,
        role: storage.role,
      );
      state = auth;
      authStateNotifier.value = auth;
    }
  }

  Future<void> login(String userId, String token, String role) async {
    await storage.setToken(token);
    await storage.setUserId(userId);
    await storage.setRole(role);
    final auth = AuthState(isLoggedIn: true, userId: userId, role: role);
    state = auth;
    authStateNotifier.value = auth;
  }

  Future<void> logout() async {
    await storage.clearAuth();
    state = const AuthState(isLoggedIn: false);
    authStateNotifier.value = const AuthState(isLoggedIn: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AuthNotifier(storage: storage);
});

/// Used by GoRouter as a [refreshListenable] so redirects re-evaluate on auth changes.
final ValueNotifier<AuthState?> authStateNotifier =
    ValueNotifier<AuthState?>(null);
