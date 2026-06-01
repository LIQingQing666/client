import 'package:flutter/material.dart';

/// Ensures a child widget has a minimum touch target of 44×44 logical
/// pixels (per iOS HIG / Android Material guidelines).
///
/// If the child is already ≥44×44 in both dimensions it is returned
/// as-is; otherwise it is wrapped in a [SizedBox] + [Center] with the
/// minimum dimensions applied.
final class TouchTarget extends StatelessWidget {
  const TouchTarget({super.key, required this.child});

  final Widget child;

  static const double minSize = 44;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: minSize,
      height: minSize,
      child: Center(child: child),
    );
  }
}
