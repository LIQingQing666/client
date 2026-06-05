import 'package:flutter/material.dart';

abstract final class AppConstants {
  // 应用信息
  static const String appName = 'LiveCommerce';

  // API 配置
  // NOTE: baseUrl includes /api prefix for REST routes (Fastify).
  // wsUrl MUST NOT include /api — Socket.IO listens at root /socket.io.
  static const String baseUrl = 'http://192.168.50.174:3000/api';
  static const String wsUrl = 'http://192.168.50.174:3000';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // 视频预加载
  static const int preloadVideoCount = 1;             // 仅预加载下一个视频，减少 ExoPlayer 并发数
  static const bool preloadWifiOnly = true;
  static const Duration preloadTimeout = Duration(seconds: 20);
  static const Duration preloadStartupDelay = Duration(milliseconds: 1500); // 当前视频优先缓冲

  // 视频相关
  static const Duration videoFadeInDuration = Duration(milliseconds: 300);

  // 分页
  static const int pageSize = 10;

  // 缓存
  static const int maxCacheSize = 200;
  static const Duration cacheExpiry = Duration(hours: 24);
}

abstract final class AppColors {
  static const Color primary = Color(0xFFE8453C);
  static const Color secondary = Color(0xFFFF6B35);
  static const Color accent = Color(0xFFFFD700);

  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color card = Color(0xFF242424);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF999999);
  static const Color textHint = Color(0xFF666666);

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);

  static const Color divider = Color(0xFF2C2C2C);
}

abstract final class AppDimens {
  static const double paddingXs = 4.0;
  static const double paddingSm = 8.0;
  static const double paddingMd = 12.0;
  static const double paddingLg = 16.0;
  static const double paddingXl = 24.0;

  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;

  static const double iconSm = 16.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;

  static const double bottomBarHeight = 64.0;
  static const double tabBarHeight = 48.0;

  static const double productCardHeight = 120.0;
  static const double videoActionBarWidth = 56.0;
}

abstract final class AppTextStyles {
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  static const TextStyle price = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  static const TextStyle priceSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
}
