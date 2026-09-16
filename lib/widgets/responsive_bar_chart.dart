import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'adaptive_content.dart';

class ResponsiveBarChart extends StatelessWidget {
  const ResponsiveBarChart({
    super.key,
    required this.groups,
    required this.labels,
  });
  final List<BarChartGroupData> groups;
  final Map<int, String> labels;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = ContentLayout.textScale(context);
      final style = Theme.of(
        context,
      ).textTheme.labelSmall!.copyWith(fontSize: 12);
      final values = [
        0.0,
        for (final group in groups)
          for (final rod in group.barRods) rod.toY,
      ];
      final low = values.reduce(math.min);
      final high = values.reduce(math.max);
      final minY = low < 0 ? low * 1.15 : 0.0;
      final maxY = high > 0 ? high * 1.15 : 1.0;
      final formatter = NumberFormat.compact(locale: 'en');
      final interval = (maxY - minY) / 4;
      final axisValues = [
        minY,
        maxY,
        for (var i = (minY / interval).ceil();
            i <= (maxY / interval).floor();
            i++)
          i * interval,
      ];
      final axisWidth = axisValues.fold<double>(
        0,
        (width, value) => math.max(
          width,
          ContentLayout.textWidth(context, formatter.format(value), style),
        ),
      ) + 16;
      final plotWidth = math.max(1.0, constraints.maxWidth - axisWidth - 16);
      final widestLabel = labels.values.fold<double>(
        48 * scale,
        (width, label) => math.max(
          width,
          ContentLayout.textWidth(context, label, style) + 16,
        ),
      );
      final slots = (plotWidth / widestLabel).floor().clamp(
        1,
        math.max(1, groups.length),
      );
      final stride = (groups.length / slots)
          .ceil()
          .clamp(1, math.max(1, groups.length))
          .toInt();
      final shown = {
        for (var i = 0; i < groups.length; i += stride) groups[i].x,
      };
      final fittedGroups = groups.map((group) {
        final width =
            (plotWidth /
                    math.max(1, groups.length) *
                    .65 /
                    math.max(1, group.barRods.length))
                .clamp(1.0, 12.0);
        return group.copyWith(
          barsSpace: 1,
          barRods: [
            for (final rod in group.barRods) rod.copyWith(width: width),
          ],
        );
      }).toList();
      return Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 240 + 40 * scale,
          child: BarChart(
            BarChartData(
              minY: minY,
              maxY: maxY,
              barGroups: fittedGroups,
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: axisWidth,
                    interval: interval,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(formatter.format(value), style: style),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32 * scale + 8,
                    interval: 1,
                    getTitlesWidget: (value, meta) =>
                        shown.contains(value.toInt())
                        ? SideTitleWidget(
                            meta: meta,
                            fitInside: SideTitleFitInsideData.fromTitleMeta(
                              meta,
                              distanceFromEdge: 0,
                            ),
                            child: Text(
                              labels[value.toInt()] ?? '',
                              style: style,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(drawVerticalLine: false),
            ),
          ),
        ),
      );
    },
  );
}
