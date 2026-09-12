import 'package:flutter/material.dart';

/// Legacy sizing helper retained for source compatibility.
///
/// Text size is deliberately no longer scaled from the viewport width or
/// shortest side. Flutter's MediaQuery TextScaler remains in control so the
/// user's accessibility text-size setting is respected. Very small legacy
/// labels are lifted to a readable floor instead of being shrunk on phones.
class Responsive {
  Responsive._();

  static const bool showDebugOverlay = false;
  static const double minimumReadableText = 13.0;

  static double scaleFactor(BuildContext context) => 1.0;

  static double sp(BuildContext context, double fontSize) {
    return fontSize < minimumReadableText ? minimumReadableText : fontSize;
  }

  /// Charts keep their authored sizes but never fall below 12 logical pixels.
  /// Device text scaling is still applied by Flutter after this value.
  static double chartScaleFactor(BuildContext context) => 1.0;

  static double spChart(BuildContext context, double fontSize) {
    return fontSize < 12.0 ? 12.0 : fontSize;
  }
}

extension ResponsiveExt on num {
  double sp(BuildContext context) => Responsive.sp(context, toDouble());

  double spChart(BuildContext context) =>
      Responsive.spChart(context, toDouble());
}
