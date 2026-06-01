import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../api/dio_client.dart';
import '../api/recharge_api.dart';
import '../api/upload_api.dart';
import '../services/player_pool.dart';
import '../services/storage_service.dart';
import '../services/video_preload_manager.dart';
import '../services/websocket_service.dart';

final class ServiceProviderWidget extends StatelessWidget {
  const ServiceProviderWidget({
    super.key,
    required this.prefs,
    required this.hiveBox,
    required this.child,
  });

  final SharedPreferences prefs;
  final Box<dynamic> hiveBox;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        hiveBoxProvider.overrideWithValue(hiveBox),
      ],
      child: child,
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden');
});

final hiveBoxProvider = Provider<Box<dynamic>>((ref) {
  throw UnimplementedError('Must be overridden');
});

final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final box = ref.watch(hiveBoxProvider);
  return StorageService(prefs: prefs, box: box);
});

final dioClientProvider = Provider<DioClient>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return DioClient(storage: storage);
});

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return WebSocketService(storage: storage);
});

final rechargeApiProvider = Provider<RechargeApi>((ref) {
  final client = ref.watch(dioClientProvider);
  return RechargeApi(client: client);
});

final uploadApiProvider = Provider<UploadApi>((ref) {
  final client = ref.watch(dioClientProvider);
  return UploadApi(client: client);
});

final currentTabIndexProvider = StateProvider<int>((ref) => 0);

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final playerPoolProvider = Provider<PlayerPool>((ref) => PlayerPool());

final videoPreloadManagerProvider = Provider<VideoPreloadManager>((ref) {
  final pool = ref.watch(playerPoolProvider);
  final connectivity = ref.watch(connectivityProvider);
  return VideoPreloadManager(pool: pool, connectivity: connectivity);
});
