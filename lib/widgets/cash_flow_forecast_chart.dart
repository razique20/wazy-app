import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/finance.dart';
import '../theme/app_theme.dart';

/// Interactive 90-day cash flow forecast line chart & summary card.
class CashFlowForecastCard extends StatefulWidget {
  final CashFlowForecast forecast;

  const CashFlowForecastCard({
    super.key,
    required this.forecast,
  });

  @override
  State<CashFlowForecastCard> createState() => _CashFlowForecastCardState();
}

class _CashFlowForecastCardState extends State<CashFlowForecastCard> {
  int? _selectedDayIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final forecast = widget.forecast;

    final selectedPoint = _selectedDayIndex != null &&
            _selectedDayIndex! >= 0 &&
            _selectedDayIndex! < forecast.points.length
        ? forecast.points[_selectedDayIndex!]
        : null;

    final netPositive = forecast.netChange >= 0;
    final primaryLineColor = netPositive ? WazyColors.safe : WazyColors.warning;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      color: isDark ? const Color(0xFF1E2430) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: WazyColors.violetAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.show_chart_rounded,
                    color: WazyColors.violetAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '90-Day Cash-Flow Forecast',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Projected balance vs. upcoming document renewals',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metrics Summary Grid
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Projected Balance (90D)',
                    value: MoneyFormat.aed(forecast.projectedEndBalance),
                    badgeText: '${netPositive ? '+' : ''}${forecast.percentChange.toStringAsFixed(1)}%',
                    badgeColor: netPositive ? WazyColors.safe : WazyColors.danger,
                    isPositive: netPositive,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Renewal Outflows',
                    value: MoneyFormat.aed(forecast.totalRenewalOutflow),
                    badgeText: forecast.totalRenewalOutflow > 0 ? 'Document Fees' : 'No Outflows',
                    badgeColor: WazyColors.caution,
                  ),
                ),
              ],
            ),

            if (forecast.lowestBalance < 0 || forecast.lowestBalance < forecast.startingBalance * 0.5) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (forecast.lowestBalance < 0 ? WazyColors.danger : WazyColors.caution)
                      .withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (forecast.lowestBalance < 0 ? WazyColors.danger : WazyColors.caution)
                        .withAlpha(80),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      forecast.lowestBalance < 0
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline_rounded,
                      color: forecast.lowestBalance < 0 ? WazyColors.danger : WazyColors.caution,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        forecast.lowestBalance < 0
                            ? 'Warning: Projected negative balance of ${MoneyFormat.aed(forecast.lowestBalance)} on ${DateFormat('d MMM').format(forecast.lowestBalanceDate)}'
                            : 'Lowest projected point: ${MoneyFormat.aed(forecast.lowestBalance)} on ${DateFormat('d MMM').format(forecast.lowestBalanceDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: forecast.lowestBalance < 0 ? WazyColors.danger : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Interactive Line Chart
            SizedBox(
              height: 180,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onPanUpdate: (details) => _handleTouch(details.localPosition, constraints.maxWidth, forecast.points.length),
                    onTapDown: (details) => _handleTouch(details.localPosition, constraints.maxWidth, forecast.points.length),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, 180),
                      painter: _CashFlowChartPainter(
                        forecast: forecast,
                        selectedIndex: _selectedDayIndex,
                        primaryColor: primaryLineColor,
                        isDark: isDark,
                        theme: theme,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Date Axis Labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today (${DateFormat('d MMM').format(forecast.startDate)})',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                ),
                Text(
                  '30D',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                ),
                Text(
                  '60D',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                ),
                Text(
                  '90D (${DateFormat('d MMM').format(forecast.endDate)})',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),

            // Selected Day Inspection Panel
            if (selectedPoint != null) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withAlpha(60),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('EEEE, d MMMM yyyy').format(selectedPoint.date),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Day ${selectedPoint.dayIndex}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Projected Balance:',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                        Text(
                          MoneyFormat.aed(selectedPoint.balance),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: selectedPoint.balance >= 0 ? WazyColors.safe : WazyColors.danger,
                          ),
                        ),
                      ],
                    ),
                    if (selectedPoint.events.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Scheduled Events:',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final ev in selectedPoint.events)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                ev.isDocumentRenewal
                                    ? Icons.assignment_rounded
                                    : (ev.kind == FinanceKind.income
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_outward_rounded),
                                size: 14,
                                color: ev.isDocumentRenewal
                                    ? WazyColors.caution
                                    : (ev.kind == FinanceKind.income ? WazyColors.safe : Colors.red),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  ev.title,
                                  style: theme.textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${ev.kind == FinanceKind.income ? '+' : '-'}${MoneyFormat.aed(ev.amount)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: ev.kind == FinanceKind.income ? WazyColors.safe : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleTouch(Offset localPos, double chartWidth, int totalPoints) {
    if (chartWidth <= 0 || totalPoints <= 0) return;
    final index = (localPos.dx / chartWidth * (totalPoints - 1)).round().clamp(0, totalPoints - 1);
    setState(() {
      _selectedDayIndex = index;
    });
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String badgeText;
  final Color badgeColor;
  final bool? isPositive;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.badgeText,
    required this.badgeColor,
    this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151922) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(50),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashFlowChartPainter extends CustomPainter {
  final CashFlowForecast forecast;
  final int? selectedIndex;
  final Color primaryColor;
  final bool isDark;
  final ThemeData theme;

  _CashFlowChartPainter({
    required this.forecast,
    required this.selectedIndex,
    required this.primaryColor,
    required this.isDark,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (forecast.points.isEmpty) return;

    final points = forecast.points;
    final totalPoints = points.length;

    // Find min and max balance values for scaling
    double minBal = points.first.balance;
    double maxBal = points.first.balance;
    for (final p in points) {
      minBal = math.min(minBal, p.balance);
      maxBal = math.max(maxBal, p.balance);
    }

    // Add 10% padding to Y range so lines don't hit exact top/bottom edges
    final yRange = (maxBal - minBal);
    final padding = yRange == 0 ? 100.0 : yRange * 0.15;
    final minY = minBal - padding;
    final maxY = maxBal + padding;
    final effectiveRange = (maxY - minY) == 0 ? 1.0 : (maxY - minY);

    double getX(int index) => (index / (totalPoints - 1)) * size.width;
    double getY(double val) => size.height - ((val - minY) / effectiveRange) * size.height;

    // Draw horizontal grid lines (0 balance line if within range, plus mid line)
    final gridPaint = Paint()
      ..color = theme.colorScheme.outlineVariant.withAlpha(40)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Zero balance line (dashed/highlighted if present)
    if (minY <= 0 && maxY >= 0) {
      final zeroY = getY(0);
      final zeroPaint = Paint()
        ..color = Colors.red.withAlpha(80)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), zeroPaint);
    }

    // Mid grid line
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint);

    // Build line path & area path
    final linePath = Path();
    final areaPath = Path();

    linePath.moveTo(getX(0), getY(points[0].balance));
    areaPath.moveTo(getX(0), size.height);
    areaPath.lineTo(getX(0), getY(points[0].balance));

    for (int i = 1; i < totalPoints; i++) {
      final x1 = getX(i - 1);
      final y1 = getY(points[i - 1].balance);
      final x2 = getX(i);
      final y2 = getY(points[i].balance);

      // Smooth bezier curves
      final controlX1 = x1 + (x2 - x1) / 2;
      final controlX2 = x1 + (x2 - x1) / 2;

      linePath.cubicTo(controlX1, y1, controlX2, y2, x2, y2);
      areaPath.cubicTo(controlX1, y1, controlX2, y2, x2, y2);
    }

    areaPath.lineTo(size.width, size.height);
    areaPath.close();

    // Draw Gradient Area under Line
    final areaGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primaryColor.withAlpha(60),
        primaryColor.withAlpha(0),
      ],
    );

    final areaPaint = Paint()
      ..shader = areaGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, areaPaint);

    // Draw Line
    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Draw Renewal Event Dot Markers along line
    final renewalDotPaint = Paint()
      ..color = WazyColors.caution
      ..style = PaintingStyle.fill;
    final renewalDotBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < totalPoints; i++) {
      if (points[i].renewalOutflow > 0) {
        final cx = getX(i);
        final cy = getY(points[i].balance);
        canvas.drawCircle(Offset(cx, cy), 5, renewalDotPaint);
        canvas.drawCircle(Offset(cx, cy), 5, renewalDotBorderPaint);
      }
    }

    // Draw Selected Indicator Line & Cursor Dot
    if (selectedIndex != null && selectedIndex! >= 0 && selectedIndex! < totalPoints) {
      final sx = getX(selectedIndex!);
      final sy = getY(points[selectedIndex!].balance);

      final indicatorPaint = Paint()
        ..color = theme.colorScheme.primary.withAlpha(180)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      // Vertical guideline
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), indicatorPaint);

      // Pulse circle
      final pulsePaint = Paint()
        ..color = theme.colorScheme.primary.withAlpha(60)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(sx, sy), 8, pulsePaint);

      // Inner dot
      final innerDotPaint = Paint()
        ..color = theme.colorScheme.primary
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(sx, sy), 4, innerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CashFlowChartPainter oldDelegate) {
    return oldDelegate.forecast != forecast ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isDark != isDark;
  }
}
