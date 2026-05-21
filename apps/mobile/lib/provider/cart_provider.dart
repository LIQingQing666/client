import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/cart_api.dart';
import '../models/cart_model.dart';
import '../services/storage_service.dart';
import '../utils/toast.dart';
import 'service_providers.dart';

final cartApiProvider = Provider<CartApi>((ref) {
  return CartApi(client: ref.watch(dioClientProvider));
});

final class CartState {
  const CartState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<CartItemModel> items;
  final bool isLoading;
  final String? errorMessage;

  bool get allSelected =>
      items.isNotEmpty && items.every((item) => item.selected);

  int get selectedCount => items.where((item) => item.selected).length;

  double get totalAmount {
    double total = 0;
    for (final item in items) {
      if (item.selected) {
        total += item.productPrice * item.quantity;
      }
    }
    return total;
  }

  List<CartItemModel> get selectedItems =>
      items.where((item) => item.selected).toList();

  CartState copyWith({
    List<CartItemModel>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final class CartNotifier extends StateNotifier<CartState> {
  CartNotifier({required this.api, required this.storage}) : super(const CartState());

  final CartApi api;
  final StorageService storage;

  String get _userId => storage.userId ?? 'u1';

  Future<void> loadCart() async {
    if (state.isLoading) {
      return;
    }
    state = state.copyWith(isLoading: true);

    try {
      final items = await api.getCart(_userId);
      if (!mounted) {
        return;
      }
      state = state.copyWith(items: items, isLoading: false);
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

  Future<void> addToCart({
    required String productId,
    String spec = '',
    int quantity = 1,
  }) async {
    try {
      await api.addToCart(
        userId: _userId,
        productId: productId,
        spec: spec,
        quantity: quantity,
      );
      await loadCart();
    }
    on Exception {
      showToast('添加商品失败，请重试');
    }
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    final original = state.items;
    final updated = original.map((item) {
      if (item.id != itemId) {
        return item;
      }
      return CartItemModel(
        id: item.id,
        userId: item.userId,
        productId: item.productId,
        productName: item.productName,
        productCover: item.productCover,
        productPrice: item.productPrice,
        productOriginalPrice: item.productOriginalPrice,
        productStock: item.productStock,
        spec: item.spec,
        quantity: quantity,
        selected: item.selected,
        productSpecs: item.productSpecs,
      );
    }).toList();
    state = state.copyWith(items: updated);

    try {
      await api.updateCartItem(itemId, quantity: quantity);
    }
    on Exception {
      state = state.copyWith(items: original);
    }
  }

  Future<void> toggleSelect(String itemId) async {
    final item = state.items.firstWhere((i) => i.id == itemId);
    final newSelected = item.selected ? 0 : 1;

    final original = state.items;
    final updated = original.map((item) {
      if (item.id != itemId) {
        return item;
      }
      return CartItemModel(
        id: item.id,
        userId: item.userId,
        productId: item.productId,
        productName: item.productName,
        productCover: item.productCover,
        productPrice: item.productPrice,
        productOriginalPrice: item.productOriginalPrice,
        productStock: item.productStock,
        spec: item.spec,
        quantity: item.quantity,
        selected: !item.selected,
        productSpecs: item.productSpecs,
      );
    }).toList();
    state = state.copyWith(items: updated);

    try {
      await api.updateCartItem(itemId, selected: newSelected);
    }
    on Exception {
      state = state.copyWith(items: original);
      showToast('操作失败');
    }
  }

  Future<void> toggleSelectAll() async {
    final newSelected = !state.allSelected ? 1 : 0;
    final original = state.items;

    final updated = original.map((item) {
      return CartItemModel(
        id: item.id,
        userId: item.userId,
        productId: item.productId,
        productName: item.productName,
        productCover: item.productCover,
        productPrice: item.productPrice,
        productOriginalPrice: item.productOriginalPrice,
        productStock: item.productStock,
        spec: item.spec,
        quantity: item.quantity,
        selected: !state.allSelected,
        productSpecs: item.productSpecs,
      );
    }).toList();
    state = state.copyWith(items: updated);

    try {
      for (final item in original) {
        await api.updateCartItem(item.id, selected: newSelected);
      }
    }
    on Exception {
      state = state.copyWith(items: original);
      showToast('操作失败');
    }
  }

  Future<void> deleteItem(String itemId) async {
    final original = state.items;
    state = state.copyWith(
      items: original.where((item) => item.id != itemId).toList(),
    );

    try {
      await api.deleteCartItem(itemId);
    }
    on Exception {
      state = state.copyWith(items: original);
      showToast('删除失败，已恢复');
    }
  }
}

final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) {
  final api = ref.watch(cartApiProvider);
  final storage = ref.watch(storageServiceProvider);
  return CartNotifier(api: api, storage: storage);
});
