import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/stats_models.dart';
import 'earnings_chart_widget.dart';
import 'date_range_selector.dart';

class PerformanceSection extends StatelessWidget {
  final PerformanceData performance;
  final Function(String?, String?) onDateRangeChanged;
  final bool isArabic;

  const PerformanceSection({
    super.key,
    required this.performance,
    required this.onDateRangeChanged,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Color(0xFF2196F3),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isArabic ? 'الأداء' : 'Performance',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall Statistics
                Text(
                  isArabic ? 'الإحصائيات العامة' : 'Overall Statistics',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),
                _buildStatisticsGrid(context, performance.statistics),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Date Range Selector - Added here, just above Period Stats
                DateRangeSelector(
                  onDateRangeChanged: onDateRangeChanged,
                  isArabic: isArabic,
                ),

                const SizedBox(height: 16),

                // Period Stats
                Text(
                  isArabic ? 'إحصائيات الفترة' : 'Period Statistics',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),
                _buildPeriodStatsGrid(context, performance.periodStats),
                if (performance.analytics.earningsChart.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  EarningsChartWidget(
                    chartData: performance.analytics.earningsChart,
                  ),
                ],
                // Best Performing Areas
                if (performance.analytics.bestPerformingAreas.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    isArabic ? 'أفضل المناطق أداءً' : 'Best Performing Areas',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...performance.analytics.bestPerformingAreas
                      .take(5)
                      .map((area) => _buildAreaCard(context, area)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid(
      BuildContext context,
      PerformanceStatistics stats,
      ) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                title: isArabic ? 'الطلبات المكتملة' : 'Completed Orders',
                value: stats.totalCompletedOrders.toString(),
                icon: Icons.check_circle,
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context: context,
                title: isArabic ? 'الطلبات الملغاة' : 'Cancelled Orders',
                value: stats.totalCancelledOrders.toString(),
                icon: Icons.cancel,
                color: const Color(0xFFF44336),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                title: isArabic ? 'التقييم' : 'Rating',
                value: stats.averageRating.toStringAsFixed(1),
                icon: Icons.star,
                color: const Color(0xFFFFB300),
                subtitle: '${stats.totalReviews} ${isArabic ? 'تقييم' : 'reviews'}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context: context,
                title: isArabic ? 'متوسط التسليم' : 'Avg Delivery',
                value: '${stats.avgDeliveryTime}',
                icon: Icons.timer,
                color: const Color(0xFF2196F3),
                subtitle: isArabic ? 'دقيقة' : 'min',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                title: isArabic ? 'معدل القبول' : 'Acceptance Rate',
                value: '${stats.acceptanceRate.toStringAsFixed(1)}%',
                icon: Icons.thumb_up,
                color: const Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context: context,
                title: isArabic ? 'معدل الإتمام' : 'Completion Rate',
                value: '${stats.completionRate.toStringAsFixed(1)}%',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF00BCD4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodStatsGrid(BuildContext context, PeriodStats stats) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                title: isArabic ? 'مكتمل' : 'Completed',
                value: stats.completedOrders.toString(),
                icon: Icons.done_all,
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context: context,
                title: isArabic ? 'ملغي' : 'Cancelled',
                value: stats.cancelledOrders.toString(),
                icon: Icons.close,
                color: const Color(0xFFF44336),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                title: isArabic ? 'الأرباح' : 'Earnings',
                value: stats.earnings.toStringAsFixed(0),
                icon: Icons.attach_money,
                color: const Color(0xFF4CAF50),
                subtitle: isArabic ? 'ج.م' : 'EGP',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context: context,
                title: isArabic ? 'العروض المقبولة' : 'Accepted Proposals',
                value: '${stats.acceptedProposals}/${stats.totalProposals}',
                icon: Icons.local_offer,
                color: const Color(0xFF9C27B0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAreaCard(BuildContext context, PerformingArea area) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final areaDisplayName = isArabic ? area.areaNameAr : area.areaName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.location_on,
              color: Color(0xFF4CAF50),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  areaDisplayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${area.ordersCount} ${isArabic ? 'توصيلة' : 'deliveries'} • ${area.earnings.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'EGP'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}