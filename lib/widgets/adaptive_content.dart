import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Layout decisions use the space assigned to the component, after padding.
class ContentLayout {
  static const maxWidth = 1440.0;
  static const gap = 12.0;

  static double textScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(16) / 16;

  static double textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: ContentLayout.maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// Natural-height items: no aspect ratio, intrinsic pass or nested grid scroll.
class AdaptiveItems extends StatelessWidget {
  const AdaptiveItems({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.maxColumns = 3,
    this.scaleWithText = true,
  });
  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final bool scaleWithText;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minimum = minItemWidth *
          (scaleWithText ? math.max(1.0, ContentLayout.textScale(context)) : 1);
      final columns = constraints.maxWidth < 328
          ? 1
          : ((constraints.maxWidth + ContentLayout.gap) /
                  (minimum + ContentLayout.gap))
              .floor()
              .clamp(1, maxColumns);
      final width = (constraints.maxWidth - (columns - 1) * ContentLayout.gap) /
          columns;
      return Wrap(
        spacing: ContentLayout.gap,
        runSpacing: ContentLayout.gap,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

class AmountText extends StatelessWidget {
  const AmountText(this.amount, {super.key, this.style, this.unit = 'ر.س'});
  final num amount;
  final TextStyle? style;
  final String unit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final number = NumberFormat('#,##0.00', 'en').format(amount);
      var numberStyle = style ?? Theme.of(context).textTheme.titleSmall!;
      // Reflow first. Only an unusually long headline value switches to body
      // typography; the system TextScaler is always preserved.
      if (ContentLayout.textWidth(context, number, numberStyle) > constraints.maxWidth) {
        numberStyle = numberStyle.copyWith(fontSize: 16);
      }
      return Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(number, textDirection: TextDirection.ltr, softWrap: false, style: numberStyle),
          Text(unit, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: numberStyle.color)),
        ],
      );
    },
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.unit = 'ر.س',
    this.isMoney = true,
  });
  final String title;
  final num value;
  final IconData icon;
  final Color color;
  final String unit;
  final bool isMoney;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, size: 20, color: color),
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (isMoney)
            AmountText(value, style: Theme.of(context).textTheme.headlineSmall)
          else ...[
            Text(NumberFormat('#,##0', 'en').format(value),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.headlineSmall),
            Text(unit, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    ),
  );
}

class LabelledAmount extends StatelessWidget {
  const LabelledAmount(this.label, this.value, {super.key, this.color});
  final String label;
  final num value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      AmountText(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
    ],
  );
}

class ActionLabel extends StatelessWidget {
  const ActionLabel(this.icon, this.label, {super.key});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 20), const SizedBox(width: 8), Flexible(child: Text(label))],
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.heading)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}
