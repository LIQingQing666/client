import 'package:flutter/material.dart';

import '../core/app_constants.dart';

/// Toast 消息类型，决定背景色和图标
enum ToastType {
  /// 成功操作：加入购物车、确认收货、领取优惠券等 ✅
  success,

  /// 错误/失败：创建订单失败、网络错误等 ❌
  error,

  /// 警告提示：请选择商品、余额不足等 ⚠️
  warning,

  /// 普通信息：开发中提示、操作指引等 ℹ️
  info,
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 显示带颜色和图标的标准 Toast
///
/// 根据 [type] 自动匹配背景色和前置图标：
/// - [success] → 绿色背景 + ✅ 勾号
/// - [error]   → 红色背景 + ❌ 叉号
/// - [warning] → 橙色背景 + ⚠️ 警告
/// - [info]    → 深色半透明背景 (默认)
void showToast(
  String message, {
  ToastType type = ToastType.info,
}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;

  final (Color bg, IconData icon) = switch (type) {
    ToastType.success => (const Color(0xFF4CAF50), Icons.check_circle_outline),
    ToastType.error   => (const Color(0xFFE53935), Icons.error_outline),
    ToastType.warning => (const Color(0xFFFFA726), Icons.warning_amber_outlined),
    ToastType.info    => (Colors.grey.shade800, Icons.info_outline),
  };

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}

/// 白色背景红色文字的收藏/喜欢 Toast（特殊样式，保留）
void showFavoriteToast(String message) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// 带重试按钮的 Toast（用于错误重试场景）
void showRetryToast(
  String message, {
  required VoidCallback onRetry,
}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      backgroundColor: const Color(0xFFFFA726),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      action: SnackBarAction(
        label: '重试',
        textColor: Colors.white,
        onPressed: onRetry,
      ),
    ),
  );
}
