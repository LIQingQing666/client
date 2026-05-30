import 'package:flutter/material.dart';

/// Responsive design helpers.
abstract final class ResponsiveHelper {
  /// True when the screen width is < 360 logical pixels (small phones like
  /// iPhone SE).
  static bool isSmallScreen(BuildContext context) =>
      MediaQuery.of(context).size.width < 360;

  /// Returns a font size scaled down for small screens.
  static double adaptiveFontSize(BuildContext context, double base) =>
      isSmallScreen(context) ? base * 0.85 : base;

  /// Returns spacing scaled down for small screens.
  static double adaptiveSpacing(BuildContext context, double base) =>
      isSmallScreen(context) ? base * 0.75 : base;

  /// Minimum touch target per iOS HIG / Android Material.
  static const double minTouchTarget = 44;
}
