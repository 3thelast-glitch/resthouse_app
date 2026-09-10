import 'package:flutter/material.dart';

/// Shared responsive helpers used by the existing pages.
///
/// Font sizes remain close to their authored logical size on phones. System
/// accessibility text scaling is still applied by Flutter; this helper does
/// not disable or clamp it.
class Responsive {
  Responsive._();

  static const bool showDebugOverlay = false;

  static const double compactBreakpoint = 600;
  static const double expandedBreakpoint = 1024;
  static const double maxContentWidth = 1360;

  static double widthOf(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isCompact(BuildContext context) =>
      widthOf(context) < compactBreakpoint;

  static bool isMedium(BuildContext context) {
    final width = widthOf(context);
    return width >= compactBreakpoint && width < expandedBreakpoint;
  }

  static bool isExpanded(BuildContext context) =>
      widthOf(context) >= expandedBreakpoint;

  /// A restrained authored-size adjustment. This replaces the previous
  /// shortest-side scaling that made already-small phone text even smaller.
  static double scaleFactor(BuildContext context) {
    final width = widthOf(context);
    if (width < compactBreakpoint) return 1;
    if (width < expandedBreakpoint) return 1.02;
    return 1.04;
  }

  static double sp(BuildContext context, double fontSize) {
    return fontSize * scaleFactor(context);
  }

  /// Charts need stable labels more than aggressive device-based scaling.
  static double chartScaleFactor(BuildContext context) {
    final width = widthOf(context);
    if (width < compactBreakpoint) return 1;
    if (width < expandedBreakpoint) return 1.01;
    return 1.03;
  }

  static double spChart(BuildContext context, double fontSize) {
    return fontSize * chartScaleFactor(context);
  }

  static EdgeInsetsDirectional pagePadding(BuildContext context) {
    final width = widthOf(context);
    final horizontal = width < compactBreakpoint
        ? 16.0
        : width < expandedBreakpoint
            ? 24.0
            : 32.0;
    final vertical = width < compactBreakpoint ? 16.0 : 24.0;
    return EdgeInsetsDirectional.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    );
  }

  static double readableContentWidth(
    BuildContext context, {
    double maximum = maxContentWidth,
  }) {
    final available = widthOf(context);
    final padding = pagePadding(context);
    final horizontalPadding = padding.start + padding.end;
    return (available - horizontalPadding).clamp(0, maximum).toDouble();
  }

  static int columnsFor(
    BuildContext context, {
    int compact = 1,
    int medium = 2,
    int expanded = 4,
  }) {
    if (isCompact(context)) return compact;
    if (isMedium(context)) return medium;
    return expanded;
  }
}

extension ResponsiveExt on num {
  double sp(BuildContext context) => Responsive.sp(context, toDouble());

  double spChart(BuildContext context) =>
      Responsive.spChart(context, toDouble());
}
