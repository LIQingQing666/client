import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/customer_service_api.dart';
import '../models/customer_service_model.dart';
import 'service_providers.dart';

final customerServiceApiProvider = Provider<CustomerServiceApi>((ref) {
  return CustomerServiceApi(client: ref.watch(dioClientProvider));
});

final class CustomerServiceState {
  const CustomerServiceState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
  });

  final List<CsMessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;

  CustomerServiceState copyWith({
    List<CsMessageModel>? messages,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
  }) {
    return CustomerServiceState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
    );
  }
}

final class CustomerServiceNotifier extends StateNotifier<CustomerServiceState> {
  CustomerServiceNotifier({required this.api}) : super(const CustomerServiceState());

  final CustomerServiceApi api;

  /// 加载聊天历史
  Future<void> loadMessages({
    required String orderId,
    required String userId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final messages = await api.getMessages(
        orderId: orderId,
        userId: userId,
      );
      if (mounted) {
        state = state.copyWith(
          messages: messages,
          isLoading: false,
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// 发送消息
  Future<List<CsMessageModel>?> sendMessage({
    required String orderId,
    required String userId,
    required String content,
    String? msgType,
  }) async {
    state = state.copyWith(isSending: true);
    try {
      final newMessages = await api.sendMessage(
        orderId: orderId,
        userId: userId,
        content: content,
        msgType: msgType,
      );
      if (mounted) {
        state = state.copyWith(
          messages: [...state.messages, ...newMessages],
          isSending: false,
        );
      }
      return newMessages;
    } on Exception catch (e) {
      if (mounted) {
        state = state.copyWith(
          isSending: false,
          errorMessage: e.toString(),
        );
      }
      return null;
    }
  }
}

final customerServiceProvider =
    StateNotifierProvider<CustomerServiceNotifier, CustomerServiceState>((ref) {
  final api = ref.watch(customerServiceApiProvider);
  return CustomerServiceNotifier(api: api);
});
