import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../api/live_api.dart';
import '../models/live_model.dart';
import '../models/product_model.dart';
import '../services/websocket_service.dart';
import 'service_providers.dart';

final liveApiProvider = Provider<LiveApi>((ref) {
  return LiveApi(client: ref.watch(dioClientProvider));
});

final class LiveState {
  const LiveState({
    this.room,
    this.messages = const [],
    this.onlineCount = 0,
    this.likeCount = 0,
    this.isLiked = false,
    this.heatCount = 0,
    this.currentProduct,
    this.products = const [],
    this.coupons = const [],
    this.isLoading = false,
    this.isConnected = false,
    this.errorMessage,
  });

  final LiveRoomInfo? room;
  final List<LiveMessage> messages;
  final int onlineCount;
  final int likeCount;
  final bool isLiked;
  final int heatCount;
  final ProductModel? currentProduct;
  final List<ProductModel> products;
  final List<LiveCoupon> coupons;
  final bool isLoading;
  final bool isConnected;
  final String? errorMessage;

  String get onlineCountText {
    if (onlineCount >= 10000) {
      return '${(onlineCount / 10000).toStringAsFixed(1)}万';
    }
    return onlineCount.toString();
  }

  String get heatCountText {
    if (heatCount >= 10000) {
      return '${(heatCount / 10000).toStringAsFixed(1)}万热度';
    }
    return '$heatCount热度';
  }

  LiveState copyWith({
    LiveRoomInfo? room,
    List<LiveMessage>? messages,
    int? onlineCount,
    int? likeCount,
    bool? isLiked,
    int? heatCount,
    ProductModel? currentProduct,
    List<ProductModel>? products,
    List<LiveCoupon>? coupons,
    bool? isLoading,
    bool? isConnected,
    String? errorMessage,
  }) {
    return LiveState(
      room: room ?? this.room,
      messages: messages ?? this.messages,
      onlineCount: onlineCount ?? this.onlineCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      heatCount: heatCount ?? this.heatCount,
      currentProduct: currentProduct ?? this.currentProduct,
      products: products ?? this.products,
      coupons: coupons ?? this.coupons,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      errorMessage: errorMessage,
    );
  }
}

final class LiveNotifier extends StateNotifier<LiveState> {
  LiveNotifier({
    required this.api,
    required this.wsService,
  }) : super(const LiveState()){

  }

  final LiveApi api;
  final WebSocketService wsService;
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  bool _active = false;
  static const int _maxMessages = 200;

  Future<void> enterRoom(String roomId) async {
    // Mark the room as active — events received before this flag is
    // cleared in leaveRoom() are safe to process.  Set synchronously
    // so _handleEvent can rely on it even before the first await.
    _active = true;
    // Cancel any previous subscription before re-entering.
    _eventSub?.cancel();
    _eventSub = null;
    state = state.copyWith(isLoading: true);

    try {
      final detail = await api.getRoomDetail(roomId);
      if (!mounted) return;
      ProductModel? initialProduct;
      if (detail.room.currentProductId != null && detail.products.isNotEmpty) {
        try {
          initialProduct = detail.products.firstWhere(
                (p) => p.id == detail.room.currentProductId,
          );
        } catch (e) {
          initialProduct = detail.products.first;
        }
      } else if (detail.products.isNotEmpty) {
        initialProduct = detail.products.first;
      }
      state = state.copyWith(
        room: detail.room,
        products: detail.products,
        coupons: detail.coupons,
        heatCount: detail.room.heatCount,
        currentProduct: initialProduct,
        isLoading: false,
      );
    }
    on Exception catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return;
    }

    // Connect WebSocket
    try {
      await wsService.connect(roomId);
      if (!mounted) return;
      wsService.joinRoom(roomId);
      _eventSub = wsService.eventStream.listen(_handleEvent);
      state = state.copyWith(isConnected: true);
    } catch (e) {
      debugPrint('WebSocket 连接失败: $e');
      // WebSocket 失败不影响页面显示
      if (!mounted) return;
      state = state.copyWith(isConnected: false);
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    // _active is cleared synchronously in leaveRoom() BEFORE _eventSub is
    // cancelled.  This guards against events already queued in the microtask
    // queue — cancel() prevents new events but can't stop scheduled ones.
    // Without this guard, those events would set state on a disposed notifier
    // and crash the framework via listener notifications on defunct widgets.
    if (!_active) return;
    try {
      final eventName = event['event'] as String? ?? '';

      switch (eventName) {
        case 'danmaku':
          _addMessage(LiveMessage.fromJson(event));
        case 'online_count':
          final count = (event['count'] as num?)?.toInt() ?? state.onlineCount;
          state = state.copyWith(onlineCount: count);
        case 'explaining_product':
          final rawProduct = event['product'] as Map<String, dynamic>?;
          if (rawProduct != null) {
            state = state.copyWith(
              currentProduct: ProductModel.fromJson(rawProduct),
            );
          }
        case 'new_comment':
          // Live room user comment broadcast.
          _addMessage(LiveMessage.fromJson(event));
        case 'stock_update':
          // Product stock change pushed by server.
          final productId = event['product_id'] as String?;
          final newStock = (event['stock'] as num?)?.toInt();
          if (productId != null && newStock != null) {
            final updated = state.products.map((p) {
              if (p.id != productId) return p;
              return p.copyWith(stock: newStock);
            }).toList();
            state = state.copyWith(products: updated);
          }
        case 'room_state':
          final count = (event['online_count'] as num?)?.toInt() ?? 0;
          final heat = (event['heat_count'] as num?)?.toInt();
          state = state.copyWith(onlineCount: count, heatCount: heat);

          // Handle current explaining product for new joiners
          final rawCurrentProduct = event['current_product'] as Map<String, dynamic>?;
          if (rawCurrentProduct != null) {
            state = state.copyWith(
              currentProduct: ProductModel.fromJson(rawCurrentProduct),
            );
          }
        case 'room_products':
          final rawList = (event['list'] as List<dynamic>?) ?? [];
          final products = rawList
              .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
              .toList();
          ProductModel? updatedCurrentProduct = state.currentProduct;
          if (updatedCurrentProduct != null) {
            try {
              updatedCurrentProduct = products.firstWhere(
                    (p) => p.id == updatedCurrentProduct!.id,
              );
            } catch (_) {
              // 当前商品不在新列表中，保持原值或设为第一个
              updatedCurrentProduct = products.isNotEmpty ? products.first : null;
            }
          }
          state = state.copyWith(products: products);
      }
    } catch (e, stack) {
      debugPrint(stack.toString());
    }
  }

  void _addMessage(LiveMessage message) {
    final messages = [...state.messages, message];
    if (messages.length > _maxMessages) {
      messages.removeRange(0, messages.length - _maxMessages);
    }
    state = state.copyWith(messages: messages);
  }

  void sendMessage(String content) {
    wsService.emit('send_message', <String, String>{
      'room': state.room?.id ?? '',
      'user_id': 'u1',
      'content': content,
    });
    // Optimistically add own message
    _addMessage(
      LiveMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userName: '我',
        content: content,
        type: 'user',
        timestamp: DateTime.now().toIso8601String(),
      ),
    );
  }

  /// Adds a local gift notification as a system message (scrolls in comment area).
  void sendGift(String userName, String giftIcon, String giftName) {
    _addMessage(
      LiveMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userName: userName,
        content: '送出了 $giftIcon $giftName',
        type: 'system',
        timestamp: DateTime.now().toIso8601String(),
      ),
    );
  }

  Future<void> switchRoom(String newRoomId) async {
    if (state.room?.id == newRoomId) return;
    _eventSub?.cancel();
    if (state.room != null) {
      wsService.leaveRoom(state.room!.id);
    }
    await enterRoom(newRoomId);
  }

  void toggleLike() {
    final newLiked = !state.isLiked;
    state = state.copyWith(
      isLiked: newLiked,
      likeCount: state.likeCount + (newLiked ? 1 : -1),
    );
  }

  void leaveRoom() {
    // Set _active = false SYNCHRONOUSLY first so that any WebSocket
    // events already queued in the microtask queue are silently dropped
    // by _handleEvent instead of triggering state updates on disposed
    // widgets.  _eventSub?.cancel() prevents future events but cannot
    // cancel already-scheduled microtasks.
    _active = false;
    // Cancel the WebSocket event subscription so that events arriving
    // after the widget has been disposed don't trigger state updates on
    // listeners that no longer exist.  switchRoom() cancels _eventSub
    // explicitly before calling wsService.leaveRoom() directly, so the
    // double-cancel here is harmless.
    _eventSub?.cancel();
    _eventSub = null;
    if (state.room != null) {
      wsService.leaveRoom(state.room!.id);
    }
  }

  @override
  void dispose() {
    _active = false;
    _eventSub?.cancel();
    leaveRoom();
    super.dispose();
  }
}

final roomListProvider = StateProvider<List<LiveRoomInfo>>((ref) => []);

final liveProvider = StateNotifierProvider<LiveNotifier, LiveState>((ref) {
  final api = ref.watch(liveApiProvider);
  final ws = ref.watch(webSocketServiceProvider);
  return LiveNotifier(api: api, wsService: ws);
});
