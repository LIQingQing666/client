import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/app_constants.dart';
import '../services/storage_service.dart';

enum WebSocketState { disconnected, connecting, connected, reconnecting }

final class WebSocketService {
  WebSocketService({required this._storage});

  final StorageService _storage;
  io.Socket? _socket;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  final _stateController = StreamController<WebSocketState>.broadcast();
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<WebSocketState> get stateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  WebSocketState _state = WebSocketState.disconnected;
  WebSocketState get state => _state;

  Stream<Map<String, dynamic>> get liveControlStream =>
      _eventController.stream.where((event) {
        final eventName = event['event'] as String? ?? '';
        return eventName == 'live_ended' ||
            eventName == 'room_disabled' ||
            eventName == 'live_status' ||
            eventName == 'live_started' ||
            eventName == 'force_leave';
      });

  void _setState(WebSocketState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Completer<void>? _connectCompleter;
  Future<void> connect(String namespace) async {
    if (_state == WebSocketState.connected ||
        _state == WebSocketState.connecting) {
      await _connectCompleter?.future;
      return;
    }

    _setState(WebSocketState.connecting);

    _connectCompleter = Completer<void>();

    final token = _storage.token;
    _socket = io.io(
      AppConstants.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .setAuth(<String, String>{
        if (token != null) 'token': token,
      })
          .setPath('/socket.io')
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _reconnectAttempts = 0;
        _setState(WebSocketState.connected);
        _socket!.emit('join', {'namespace': namespace});

        if (!_connectCompleter!.isCompleted) {
          _connectCompleter!.complete();
        }
      })
      ..onDisconnect((_) {
        _setState(WebSocketState.disconnected);
        _scheduleReconnect(namespace);
      })
      ..onConnectError((err) {
        _setState(WebSocketState.disconnected);

        if (!_connectCompleter!.isCompleted) {
          _connectCompleter!.completeError(err);
        }

        _scheduleReconnect(namespace);
      })
      ..onError((err) {
        debugPrint('[WS] error: $err');
      })
      ..onAny(_processEvent);

    _socket!.connect();

    try {
      await _connectCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[WS] ⚠️ 连接超时');
          throw TimeoutException('WebSocket 连接超时');
        },
      );
    } catch (e) {
      debugPrint('[WS] 连接失败: $e');
      rethrow;
    }
  }

  void _processEvent(String eventName, dynamic data) {
    if (data is Map) {
      _eventController.add({
        'event': eventName,
        ...Map<String, dynamic>.from(data),
      });
    } else {
      _eventController.add({
        'event': eventName,
        'data': data,
      });
    }
  }

  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  void _scheduleReconnect(String namespace) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[WS] max reconnect attempts reached');
      return;
    }
    // Prevent duplicate timers from multiple disconnect events.
    if (_reconnectTimer?.isActive == true) return;

    _setState(WebSocketState.reconnecting);
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: _getReconnectDelay());
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      unawaited(connect(namespace));
    });
  }

  int _getReconnectDelay() {
    return switch (_reconnectAttempts) {
      0 => 1,
      1 => 2,
      2 => 4,
      _ => 8,
    };
  }

  void joinRoom(String roomId) {
    _socket?.emit('join', {'room': roomId});
  }

  void leaveRoom(String roomId) {
    _socket?.emit('leave', {'room': roomId});
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _setState(WebSocketState.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _eventController.close();
  }

  void endLive(String roomId, {Map<String, dynamic>? summary}) {
    emit('end_live', {
      'room': roomId,
      'summary': summary ?? {},
    });
  }

  void getLiveStatus(String roomId) {
    emit('get_live_status', {'room': roomId});
  }

  void startLive(String roomId, {Map<String, dynamic>? liveInfo}) {
    emit('start_live', {
      'room': roomId,
      'liveInfo': liveInfo ?? {},
    });
  }
}
