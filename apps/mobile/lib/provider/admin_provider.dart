
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/admin_api.dart';
import 'service_providers.dart';

final adminApiProvider = Provider<AdminApi>((ref) {
  return AdminApi(client: ref.watch(dioClientProvider));
});

final class AdminState {
  const AdminState({
    this.data,
    this.isLoading = false,
    this.errorMessage,
  });

  final DashboardData? data;
  final bool isLoading;
  final String? errorMessage;

  AdminState copyWith({
    DashboardData? data,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AdminState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final class AdminNotifier extends StateNotifier<AdminState> {
  AdminNotifier({required this.api}) : super(const AdminState()) {
    loadDashboard();
  }

  final AdminApi api;

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await api.getDashboard();
      state = state.copyWith(data: data, isLoading: false);
    }
    on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final adminProvider =
    StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  final api = ref.watch(adminApiProvider);
  return AdminNotifier(api: api);
});
