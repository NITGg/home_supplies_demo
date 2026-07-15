import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/stats_models.dart';

class EarningsChartWidget extends StatelessWidget {
  final List<EarningsChartData> chartData;

  const EarningsChartWidget({
    super.key,
    required this.chartData,
  });

  // ---------------------------------------------------------------------------
  // Aggregation — group individual deliveries by calendar date (yyyy-MM-dd),
  // summing earnings and orders_count per day.
  //
  // The API returns one entry per delivery with a full ISO timestamp, so the
  // same calendar day can appear many times. We must fold them before plotting.
  // ---------------------------------------------------------------------------

  List<_DayAggregate> _aggregateByDay() {
    final Map<String, _DayAggregate> map = {};

    for (final item in chartData) {
      // Normalise to local date-only key so times don't split the same day
      final date = DateTime.parse(item.date).toLocal();
      final key = DateFormat('yyyy-MM-dd').format(date);

      if (map.containsKey(key)) {
        map[key] = _DayAggregate(
          date: map[key]!.date,
          earnings: map[key]!.earnings + item.earnings,
          ordersCount: map[key]!.ordersCount + item.ordersCount,
        );
      } else {
        map[key] = _DayAggregate(
          date: DateTime(date.year, date.month, date.day),
          earnings: item.earnings,
          ordersCount: item.ordersCount,
        );
      }
    }

    // Return sorted ascending by date
    return map.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (chartData.isEmpty) {
      return _buildEmptyState(context, isArabic);
    }

    final aggregated = _aggregateByDay();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.show_chart,
                    color: Color(0xFF4CAF50), size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  AppLocalizations.of(context)!.earningsOverTime,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Chart / single-point view ────────────────────────────────
          SizedBox(
            height: 220,
            child: aggregated.length == 1
                ? _buildSinglePointView(context, isArabic, aggregated.first)
                : LineChart(_buildLineChartData(context, aggregated, isArabic)),
          ),

          const SizedBox(height: 12),
          _buildLegend(context, isArabic),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Single-day view
  // ---------------------------------------------------------------------------

  Widget _buildSinglePointView(
      BuildContext context, bool isArabic, _DayAggregate day) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4CAF50).withOpacity(0.1),
              const Color(0xFF4CAF50).withOpacity(0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF4CAF50).withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up,
                size: 36, color: const Color(0xFF4CAF50).withOpacity(0.7)),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM dd, yyyy').format(day.date),
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSingleStatCard(
                  icon: Icons.attach_money,
                  label: AppLocalizations.of(context)!.earnings,
                  value:
                  '${(day.earnings/100).toStringAsFixed(0)} ${AppLocalizations.of(context)!.egp}',
                  color: const Color(0xFF4CAF50),
                ),
                _buildSingleStatCard(
                  icon: Icons.shopping_bag,
                  label: AppLocalizations.of(context)!.orders,
                  value: day.ordersCount.toString(),
                  color: const Color(0xFF2196F3),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Color(0xFFF57F17)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context)!.chartWillAppearWithMoreData,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFFF57F17)),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Line chart — built from the aggregated (one-entry-per-day) list
  // ---------------------------------------------------------------------------

  LineChartData _buildLineChartData(
      BuildContext context,
      List<_DayAggregate> days,
      bool isArabic,
      ) {
    final earningsSpots = days.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.earnings.toDouble()/100);
    }).toList();

    final maxEarnings =
    days.map((d) => d.earnings/100).reduce((a, b) => a > b ? a : b).toDouble();
    final minEarnings =
    days.map((d) => d.earnings/100).reduce((a, b) => a < b ? a : b).toDouble();

    final yPadding = (maxEarnings - minEarnings) * 0.2;
    final maxY = (maxEarnings + yPadding).ceilToDouble();
    final minY =
    minEarnings > yPadding ? (minEarnings - yPadding).floorToDouble() : 0;

    final yRange = maxY - minY;
    final interval = (yRange / 5).ceilToDouble();

    // X-axis label format depends on how many distinct days we have
    String dateLabel(DateTime date) {
      if (days.length <= 7) return DateFormat('EEE').format(date); // Mon, Tue…
      if (days.length <= 31) return DateFormat('d').format(date); // 1, 2, 3…
      return DateFormat('MM/dd').format(date); // 02/10
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: interval > 0 ? interval : 1,
        verticalInterval: 1,
        getDrawingHorizontalLine: (_) =>
        const FlLine(color: Color(0xFFE0E0E0), strokeWidth: 1),
        getDrawingVerticalLine: (_) =>
        const FlLine(color: Color(0xFFE0E0E0), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        rightTitles:
        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= days.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  dateLabel(days[idx].date),
                  style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 9,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.visible,
                  maxLines: 1,
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval > 0 ? interval : 1,
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              final label = value >= 1000
                  ? '${(value / 1000).toStringAsFixed(1)}K'
                  : value.toInt().toString();
              return SizedBox(
                width: 50,
                child: Text(
                  label,
                  style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 9,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      minX: 0,
      maxX: (days.length - 1).toDouble(),
      minY: minY.toDouble(),
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: earningsSpots,
          isCurved: true,
          curveSmoothness: 0.35,
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              radius: 5,
              color: Colors.white,
              strokeWidth: 2.5,
              strokeColor: const Color(0xFF4CAF50),
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4CAF50).withOpacity(0.3),
                const Color(0xFF4CAF50).withOpacity(0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          maxContentWidth: 180,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipColor: (_) => const Color(0xFF1A1A1A),
          tooltipBorderRadius: BorderRadius.circular(8),
          tooltipPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          getTooltipItems: (spots) {
            return spots.map((barSpot) {
              final idx = barSpot.x.toInt();
              if (idx < 0 || idx >= days.length) return null;

              final day = days[idx];
              final dateStr = DateFormat('MMM dd').format(day.date);
              final earningsStr =
                  '${(day.earnings/100).toStringAsFixed(0)} ${AppLocalizations.of(context)!.egp}';

              return LineTooltipItem(
                '$dateStr\n',
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
                children: [
                  TextSpan(
                    text:
                    '${AppLocalizations.of(context)!.earnings}: $earningsStr\n',
                    style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text:
                    '${AppLocalizations.of(context)!.orders}: ${day.ordersCount}',
                    style: const TextStyle(
                        color: Color(0xFF2196F3),
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              );
            }).toList();
          },
        ),
        handleBuiltInTouches: true,
        getTouchedSpotIndicator: (barData, spotIndexes) {
          return spotIndexes.map((_) {
            return TouchedSpotIndicatorData(
              const FlLine(
                  color: Color(0xFF4CAF50),
                  strokeWidth: 2,
                  dashArray: [5, 5]),
              FlDotData(
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 7,
                  color: Colors.white,
                  strokeWidth: 3,
                  strokeColor: const Color(0xFF4CAF50),
                ),
              ),
            );
          }).toList();
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Legend
  // ---------------------------------------------------------------------------

  Widget _buildLegend(BuildContext context, bool isArabic) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 8,
      children: [
        _buildLegendItem(
            color: const Color(0xFF4CAF50),
            label: AppLocalizations.of(context)!.earnings),
        _buildLegendItem(
            color: const Color(0xFF2196F3),
            label: AppLocalizations.of(context)!.orders,
            isSecondary: true),
      ],
    );
  }

  Widget _buildLegendItem(
      {required Color color, required String label, bool isSecondary = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isSecondary ? Colors.transparent : color,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context, bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noData,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal aggregate model — one entry per calendar day
// ---------------------------------------------------------------------------

class _DayAggregate {
  final DateTime date;
  final num earnings;
  final int ordersCount;

  const _DayAggregate({
    required this.date,
    required this.earnings,
    required this.ordersCount,
  });
}