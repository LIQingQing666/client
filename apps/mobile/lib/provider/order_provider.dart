import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../api/order_api.dart';
import '../models/cart_model.dart';
import '../models/order_model.dart';
import '../services/storage_service.dart';
import '../utils/toast.dart';
import 'service_providers.dart';

final orderApiProvider = Provider<OrderApi>((ref) {
  return OrderApi(client: ref.watch(dioClientProvider));
});

final class OrderState {
  const OrderState({
    this.orders = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.activeStatus,
    this.errorMessage,
  });

  final List<OrderModel> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final String? activeStatus;
  final String? errorMessage;

  OrderState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? activeStatus,
    String? errorMessage,
  }) {
    return OrderState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      activeStatus: activeStatus,
      errorMessage: errorMessage,
    );
  }
}

final class OrderNotifier extends StateNotifier<OrderState> {
  OrderNotifier({required this.api, required this.storage}) : super(const OrderState()) {
    loadOrders();
  }

  final OrderApi api;
  final StorageService storage;

  String get _userId => storage.userId ?? 'u1';

  Future<void> loadOrders({String? status}) async {
    if (state.isLoading) {
      return;
    }
    state = state.copyWith(
      isLoading: true,
      activeStatus: status ?? state.activeStatus,
      page: 1,
    );

    try {
      final response = await api.getOrders(
        userId: _userId,
        status: state.activeStatus,
      );
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        orders: response.list,
        isLoading: false,
        hasMore: response.hasMore,
      );
    }
    on Exception catch (e) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.page + 1;
      final response = await api.getOrders(
        userId: _userId,
        status: state.activeStatus,
        page: nextPage,
      );
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        orders: [...state.orders, ...response.list],
        isLoadingMore: false,
        hasMore: response.hasMore,
        page: nextPage,
      );
    }
    on Exception catch (e) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<CreateOrderResult?> createOrder({
    required List<CartItemModel> items,
    OrderAddress? address,
    String? couponId,
  }) async {
    try {
      final result = await api.createOrder(
        userId: _userId,
        items: items,
        address: address,
        couponId: couponId,
      );
      return result;
    }
    on Exception {
      showToast('下单失败，请重试');
      return null;
    }
  }

  Future<Map<String, dynamic>?> payOrder(String orderId, {String paymentMethod = 'wechat'}) async {
    try {
      final result = await api.payOrder(orderId, paymentMethod: paymentMethod);
      // Refresh list
      await loadOrders(status: state.activeStatus);
      return result;
    }
    on Exception {
      showToast('支付失败，请重试');
      return null;
    }
  }

  /// 确认收货，成功后返回 true
  Future<bool> confirmOrder(String orderId) async {
    try {
      await api.confirmOrder(orderId);
      showToast('确认收货成功');
      return true;
    } on ApiException catch (e) {
      showToast(e.message, isError: true);
      return false;
    } on Exception {
      showToast('确认收货失败，请重试', isError: true);
      return false;
    }
  }
}

final orderProvider =
    StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  final api = ref.watch(orderApiProvider);
  final storage = ref.watch(storageServiceProvider);
  return OrderNotifier(api: api, storage: storage);
});
