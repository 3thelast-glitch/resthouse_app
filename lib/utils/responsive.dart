import 'package:flutter/material.dart';

/// Shared adaptive-layout rules for the app.
///
/// Decisions are based on the width actually offered to a widget (typically
/// through [LayoutBuilder]) rather than a device name or raw screen pixels.
class Responsive {
  Responsive._();

  static const bool showDebugOverlay = false;
  static const double minimumReadableText = 13.0;

  static const double narrowPhone = 360.0;
  static const double compact = 600.0;
  static const double wide = 1024.0;
  static const double maxContentWidth = 1320.0;

  static const double gapSmall = 8.0;
  static const double gap = 12.0;
  static const double pagePadding = 16.0;

  /// Legacy sizing hook retained for source compatibility.
  ///
  /// Text is not scaled from viewport width. Flutter's [TextScaler] remains in
  /// control so system accessibility settings are respected.
  static double scaleFactor(BuildContext context) => 1.0;

  static double sp(BuildContext context, double fontSize) {
    return fontSize < minimumReadableText ? minimumReadableText : fontSize;
  }

  /// Charts keep their authored sizes but never fall below 12 logical pixels.
  static double chartScaleFactor(BuildContext context) => 1.0;

  static double spChart(BuildContext context, double fontSize) {
    return fontSize < 12.0 ? 12.0 : fontSize;
  }

  static double textScale(BuildContext context, {double sampleSize = 14}) {
    return MediaQuery.textScalerOf(context).scale(sampleSize) / sampleSize;
  }

  static bool hasLargeText(
    BuildContext context, {
    double threshold = 1.3,
  }) {
    return textScale(context) >= threshold;
  }

  /// Calculates how many natural-height items fit in the offered width after
  /// spacing is deducted. This is intended for [Wrap]-based responsive grids.
  static int columnCountForWidth(
    double availableWidth, {
    required double minItemWidth,
    int maxColumns = 3,
    double spacing = gap,
  }) {
    if (!availableWidth.isFinite || availableWidth <= 0) return 1;
    final raw = ((availableWidth + spacing) / (minItemWidth + spacing)).floor();
    if (raw < 1) return 1;
    if (raw > maxColumns) return maxColumns;
    return raw;
  }

  static double itemWidthForColumns(
    double availableWidth, {
    required int columns,
    double spacing = gap,
  }) {
    final safeColumns = columns < 1 ? 1 : columns;
    final totalSpacing = spacing * (safeColumns - 1);
    return (availableWidth - totalSpacing) / safeColumns;
  }
}

extension ResponsiveExt on num {
  double sp(BuildContext context) => Responsive.sp(context, toDouble());

  double spChart(BuildContext context) =>
      Responsive.spChart(context, toDouble());
}
