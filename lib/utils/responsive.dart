import 'package:flutter/material.dart';

/// Responsive font scaling utility.
/// Computes a scale factor based on screen shortest side to ensure
/// text is legible on 8.7" tablets without being oversized on larger screens.
class Responsive {
  Responsive._(); // Prevent instantiation

  /// Set to [false] to hide the debug scale overlay in production.
  static const bool showDebugOverlay = true;

  /// Reference shortest side dimension (calibrated for desktop ~600dp).
  static const double _referenceShortestSide = 600.0;

  /// Computes the responsive scale factor for the current screen.
  /// Clamped between 0.85 (small phones) and 1.4 (large tablets/desktop).
  static double scaleFactor(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    return (shortestSide / _referenceShortestSide).clamp(0.85, 1.4);
  }

  /// Scales a font size responsively based on screen dimensions.
  static double sp(BuildContext context, double fontSize) {
    return fontSize * scaleFactor(context);
  }

  /// Scale factor for chart axis labels — clamped tighter (max 1.1)
  /// to prevent label overlap on smaller screens.
  static double chartScaleFactor(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    return (shortestSide / _referenceShortestSide).clamp(0.85, 1.1);
  }

  /// Scales a font size for chart axis labels with a tighter maximum.
  static double spChart(BuildContext context, double fontSize) {
    return fontSize * chartScaleFactor(context);
  }
}

/// Extension on [num] for ergonomic responsive font sizing.
///
/// Usage:
/// ```dart
/// Text('Hello', style: TextStyle(fontSize: 14.sp(context)));
/// ```
extension ResponsiveExt on num {
  /// Scales this number as a responsive font size.
  double sp(BuildContext context) => Responsive.sp(context, toDouble());

  /// Scales this number as a responsive chart label font size (clamped tighter).
  double spChart(BuildContext context) => Responsive.spChart(context, toDouble());
}
