import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/live_model.dart';

/// State for the Picture-in-Picture floating window.
final class PipState {
  const PipState({
    this.isActive = false,
    this.videoController,
    this.roomInfo,
  });

  final bool isActive;
  final VideoPlayerController? videoController;
  final LiveRoomInfo? roomInfo;

  /// The room to navigate back to when the user taps the floating window.
  String? get pipRoomId => roomInfo?.id;

  PipState copyWith({
    bool? isActive,
    VideoPlayerController? videoController,
    LiveRoomInfo? roomInfo,
  }) {
    return PipState(
      isActive: isActive ?? this.isActive,
      videoController: videoController ?? this.videoController,
      roomInfo: roomInfo ?? this.roomInfo,
    );
  }
}

/// Manages the global PIP (Picture-in-Picture) floating window state.
///
/// When the user navigates away from the live room (e.g. to a product detail
/// page), the live video can be kept playing in a draggable floating window.
final class PipNotifier extends StateNotifier<PipState> {
  PipNotifier() : super(const PipState());

  /// Enter PIP mode with the given controller and room info.
  void enterPip(VideoPlayerController controller, LiveRoomInfo room) {
    state = state.copyWith(
      isActive: true,
      videoController: controller,
      roomInfo: room,
    );
  }

  /// Exit PIP mode and return to full live room.
  /// The controller is preserved (not disposed).
  void exitPip() {
    state = state.copyWith(isActive: false);
  }

  /// Transfer controller ownership to the caller without disposing it.
  /// Used when the live-room page reuses a PIP controller.
  void releaseController() {
    state = const PipState();
  }

  /// Completely close the PIP window and dispose resources.
  void closePip() {
    state.videoController?.pause();
    state.videoController?.dispose();
    state = const PipState();
  }

  @override
  void dispose() {
    // Don't dispose controller here — it may be reused.
    // The owner (LiveRoomPage) is responsible for cleanup.
    super.dispose();
  }
}

/// Global provider for PIP state.
final pipProvider = StateNotifierProvider<PipNotifier, PipState>((ref) {
  return PipNotifier();
});
