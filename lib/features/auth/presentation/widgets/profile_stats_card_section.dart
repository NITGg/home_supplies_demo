import 'package:flutter/material.dart';
import 'package:tawreedat_courier/core/style/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/user_profile_model.dart';

class StatsCardsSection extends StatelessWidget {
  final CourierStatsModel stats;

  const StatsCardsSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Center(
        // prevents stretching too much on desktop
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.performanceMetrics,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 16),

                /// ===== MAIN STATS GRID =====
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280, // 👈 card max width
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  children: [
                    _buildStatCard(
                      title: localizations.completed,
                      value: stats.totalCompletedOrders.toString(),
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF00B894),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    _buildStatCard(
                      title: localizations.earnings,
                      value: '${stats.totalEarnings} ${localizations.egp}',
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFF6C5CE7),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    _buildStatCard(
                      title: localizations.rating,
                      value:
                      double.parse(stats.averageRating).toStringAsFixed(1),
                      icon: Icons.star_outline,
                      color: const Color(0xFFFDCB6E),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFDCB6E), Color(0xFFF9CA24)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    _buildStatCard(
                      title: localizations.completionRate,
                      value: '${stats.completionRate}%',
                      icon: Icons.pie_chart_outline,
                      color: const Color(0xFF0984E3),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0984E3), Color(0xFF74B9FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                /// ===== MINI STATS GRID =====
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250, // smaller width for mini cards
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 3.0, // wider row-style card
                  ),
                  children: [
                    _buildMiniStatCard(
                      localizations.acceptanceRate,
                      '${stats.acceptanceRate}%',
                      Icons.thumb_up_outlined,
                    ),
                    _buildMiniStatCard(
                      localizations.avgDeliveryTime,
                      '${stats.avgDeliveryTime} ${localizations.min}',
                      Icons.timer_outlined,
                    ),
                    _buildMiniStatCard(
                      localizations.totalReviews,
                      stats.totalReviews.toString(),
                      Icons.rate_review_outlined,
                    ),
                    _buildMiniStatCard(
                      localizations.cancelled,
                      stats.totalCancelledOrders.toString(),
                      Icons.cancel_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= CARDS =================

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.kPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.kPrimaryColor),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
