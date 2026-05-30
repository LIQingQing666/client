import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      currentProduct: currentProduct,
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
  }) : super(const LiveState());

  final LiveApi api;
  final WebSocketService wsService;
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  static const int _maxMessages = 200;

  Future<void> enterRoom(String roomId) async {
    state = state.copyWith(isLoading: true);

    try {
      final detail = await api.getRoomDetail(roomId);
      state = state.copyWith(
        room: detail.room,
        products: detail.products,
        coupons: detail.coupons,
        heatCount: detail.room.heatCount,
        isLoading: false,
      );
    }
    on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return;
    }

    // Connect WebSocket
    await wsService.connect(roomId);
    wsService.joinRoom(roomId);

    _eventSub = wsService.eventStream.listen(_handleEvent);

    state = state.copyWith(isConnected: true);
  }

  void _handleEvent(Map<String, dynamic> event) {
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
      case 'room_state':
        final count = (event['online_count'] as num?)?.toInt() ?? 0;
        final heat = (event['heat_count'] as num?)?.toInt();
        state = state.copyWith(onlineCount: count, heatCount: heat);
      case 'room_products':
        final rawList = (event['list'] as List<dynamic>?) ?? [];
        final products = rawList
            .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(products: products);
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
    if (state.room != null) {
      wsService.leaveRoom(state.room!.id);
    }
  }

  @override
  void dispose() {
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
