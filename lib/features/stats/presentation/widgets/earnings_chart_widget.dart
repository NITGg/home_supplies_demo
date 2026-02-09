import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/models/stats_models.dart';

class EarningsChartWidget extends StatelessWidget {
  final List<EarningsChartData> chartData;

  const EarningsChartWidget({
    super.key,
    required this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (chartData.isEmpty) {
      return _buildEmptyState(context, isArabic);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.show_chart,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  isArabic ? 'الأرباح على مدار الوقت' : 'Earnings Over Time',
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
          SizedBox(
            height: 220,
            child: chartData.length == 1
                ? _buildSinglePointView(context, isArabic)
                : LineChart(_buildLineChartData(context)),
          ),
          const SizedBox(height: 12),
          _buildLegend(context, isArabic),
        ],
      ),
    );
  }

  Widget _buildSinglePointView(BuildContext context, bool isArabic) {
    final data = chartData.first;
    final date = DateTime.parse(data.date);

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
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.trending_up,
              size: 36,
              color: const Color(0xFF4CAF50).withOpacity(0.7),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM dd, yyyy').format(date),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
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
                  label: isArabic ? 'الأرباح' : 'Earnings',
                  value: '${data.earnings.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'EGP'}',
                  color: const Color(0xFF4CAF50),
                ),
                _buildSingleStatCard(
                  icon: Icons.shopping_bag,
                  label: isArabic ? 'الطلبات' : 'Orders',
                  value: data.ordersCount.toString(),
                  color: const Color(0xFF2196F3),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Color(0xFFF57F17),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isArabic
                          ? 'سيظهر الرسم البياني مع المزيد من البيانات'
                          : 'Chart will appear with more data',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFF57F17),
                      ),
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
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Sort data by date
    final sortedData = List<EarningsChartData>.from(chartData)
      ..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

    // Create spots for earnings
    final earningsSpots = sortedData.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.earnings.toDouble(),
      );
    }).toList();

    // Find max values for scaling
    final maxEarnings = sortedData.map((e) => e.earnings).reduce((a, b) => a > b ? a : b).toDouble();
    final minEarnings = sortedData.map((e) => e.earnings).reduce((a, b) => a < b ? a : b).toDouble();

    // Calculate Y-axis range with padding
    final yPadding = (maxEarnings - minEarnings) * 0.2;
    final maxY = (maxEarnings + yPadding).ceilToDouble();
    final minY = minEarnings > yPadding ? (minEarnings - yPadding).floorToDouble() : 0;

    // Determine interval for better spacing
    final yRange = maxY - minY;
    final interval = (yRange / 5).ceilToDouble();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: interval > 0 ? interval : 1,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: const Color(0xFFE0E0E0),
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: const Color(0xFFE0E0E0),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < sortedData.length) {
                final date = DateTime.parse(sortedData[value.toInt()].date);

                // Show different formats based on data range
                String dateLabel;
                if (sortedData.length <= 7) {
                  // For weekly view, show day names
                  dateLabel = DateFormat('EEE').format(date);
                } else if (sortedData.length <= 31) {
                  // For monthly view, show date
                  dateLabel = DateFormat('d').format(date);
                } else {
                  // For longer periods, show month/day
                  dateLabel = DateFormat('MM/dd').format(date);
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.visible,
                    maxLines: 1,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval > 0 ? interval : 1,
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              // Format large numbers with K suffix
              String label;
              if (value >= 1000) {
                label = '${(value / 1000).toStringAsFixed(1)}K';
              } else {
                label = value.toInt().toString();
              }

              return SizedBox(
                width: 50,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
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
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      minX: 0,
      maxX: (sortedData.length - 1).toDouble(),
      minY: minY.toDouble(),
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: earningsSpots,
          isCurved: true,
          curveSmoothness: 0.35,
          gradient: const LinearGradient(
            colors: [
              Color(0xFF4CAF50),
              Color(0xFF66BB6A),
            ],
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 5,
                color: Colors.white,
                strokeWidth: 2.5,
                strokeColor: const Color(0xFF4CAF50),
              );
            },
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
          getTooltipColor: (touchedSpot) => const Color(0xFF1A1A1A),
          tooltipBorderRadius: BorderRadius.circular(8),
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final index = barSpot.x.toInt();
              if (index >= 0 && index < sortedData.length) {
                final data = sortedData[index];
                final date = DateTime.parse(data.date);
                final dateStr = DateFormat('MMM dd').format(date);
                final earningsStr = '${data.earnings.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'EGP'}';
                final ordersStr = '${data.ordersCount}';

                return LineTooltipItem(
                  '$dateStr\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  children: [
                    TextSpan(
                      text: '${isArabic ? 'الأرباح' : 'Earnings'}: $earningsStr\n',
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '${isArabic ? 'الطلبات' : 'Orders'}: $ordersStr',
                      style: const TextStyle(
                        color: Color(0xFF2196F3),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }
              return null;
            }).toList();
          },
        ),
        handleBuiltInTouches: true,
        getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
          return spotIndexes.map((spotIndex) {
            return TouchedSpotIndicatorData(
              FlLine(
                color: const Color(0xFF4CAF50),
                strokeWidth: 2,
                dashArray: [5, 5],
              ),
              FlDotData(
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 7,
                    color: Colors.white,
                    strokeWidth: 3,
                    strokeColor: const Color(0xFF4CAF50),
                  );
                },
              ),
            );
          }).toList();
        },
      ),
    );
  }

  Widget _buildLegend(BuildContext context, bool isArabic) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 8,
      children: [
        _buildLegendItem(
          color: const Color(0xFF4CAF50),
          label: isArabic ? 'الأرباح' : 'Earnings',
        ),
        _buildLegendItem(
          color: const Color(0xFF2196F3),
          label: isArabic ? 'الطلبات' : 'Orders',
          isSecondary: true,
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    bool isSecondary = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isSecondary ? Colors.transparent : color,
            border: Border.all(
              color: color,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }

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
            Icon(
              Icons.show_chart,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'لا توجد بيانات للعرض' : 'No data to display',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}