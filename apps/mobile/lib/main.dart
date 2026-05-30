import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'provider/pip_provider.dart';
import 'provider/service_providers.dart';
import 'utils/toast.dart';
import 'widgets/floating_video_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  final hiveBox = await Hive.openBox<dynamic>('app_storage');
  final prefs = await SharedPreferences.getInstance();

  // Image cache: limit memory usage to ~50 MB.
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;

  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]),
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ServiceProviderWidget(
      prefs: prefs,
      hiveBox: hiveBox,
      child: const CommerceApp(),
    ),
  );
}

final class CommerceApp extends ConsumerWidget {
  const CommerceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipState = ref.watch(pipProvider);

    return MaterialApp.router(
      title: 'LiveCommerce',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            // PIP floating window overlay
            if (pipState.isActive &&
                pipState.videoController != null &&
                pipState.roomInfo != null)
              FloatingVideoPlayer(
                controller: pipState.videoController!,
                roomInfo: pipState.roomInfo!,
                onTap: () {
                  final roomId = pipState.pipRoomId;
                  ref.read(pipProvider.notifier).exitPip();
                  if (roomId != null) {
                    // Navigate back to the live room via the global router.
                    // Pop any intermediate routes first, then go to the room.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final router = AppRouter.router;
                      while (router.canPop()) {
                        router.pop();
                      }
                      router.pushNamed('liveRoom',
                          pathParameters: {'roomId': roomId});
                    });
                  }
                },
                onClose: () {
                  ref.read(pipProvider.notifier).closePip();
                },
              ),
          ],
        );
      },
    );
  }
}
