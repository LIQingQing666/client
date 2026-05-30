import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showToast(String message, {bool isError = false}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) {
    return;
  }

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      backgroundColor: isError ? Colors.redAccent : Colors.grey.shade800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

/// Shows a SnackBar with a retry action button.
/// [onRetry] is called when the user taps "重试".
void showRetryToast(String message, {required VoidCallback onRetry}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) {
    return;
  }

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      backgroundColor: Colors.orange.shade800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      action: SnackBarAction(
        label: '重试',
        textColor: Colors.white,
        onPressed: onRetry,
      ),
    ),
  );
}
