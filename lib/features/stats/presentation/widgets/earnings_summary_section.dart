import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/stats_models.dart';

class EarningsSummarySection extends StatelessWidget {
  final EarningsSummaryData earningsSummary;

  const EarningsSummarySection({
    super.key,
    required this.earningsSummary,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isArabic ? 'ملخص الأرباح' : 'Earnings Summary',
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
              children: [
                // Today
                _buildEarningsPeriodCard(
                  context: context,
                  title: isArabic ? 'اليوم' : 'Today',
                  earnings: earningsSummary.today.earnings,
                  deliveries: earningsSummary.today.deliveries,
                  icon: Icons.today,
                  color: const Color(0xFF2196F3),
                ),
                const SizedBox(height: 12),

                // This Week
                _buildEarningsPeriodCard(
                  context: context,
                  title: isArabic ? 'هذا الأسبوع' : 'This Week',
                  earnings: earningsSummary.thisWeek.earnings,
                  deliveries: earningsSummary.thisWeek.deliveries,
                  icon: Icons.date_range,
                  color: const Color(0xFF9C27B0),
                ),
                const SizedBox(height: 12),

                // This Month
                _buildEarningsPeriodCard(
                  context: context,
                  title: isArabic ? 'هذا الشهر' : 'This Month',
                  earnings: earningsSummary.thisMonth.earnings,
                  deliveries: earningsSummary.thisMonth.deliveries,
                  icon: Icons.calendar_month,
                  color: const Color(0xFFFF9800),
                ),
                const SizedBox(height: 12),

                // Total
                _buildEarningsPeriodCard(
                  context: context,
                  title: isArabic ? 'الإجمالي' : 'Total',
                  earnings: earningsSummary.total.earnings,
                  deliveries: earningsSummary.total.deliveries,
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xFF4CAF50),
                  isTotal: true,
                ),

                // Unpaid Commissions
                if (earningsSummary.unpaidCommissions.count > 0) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildUnpaidCommissionsCard(
                    context: context,
                    count: earningsSummary.unpaidCommissions.count,
                    totalAmount: earningsSummary.unpaidCommissions.totalAmount,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsPeriodCard({
    required BuildContext context,
    required String title,
    required num earnings,
    required int deliveries,
    required IconData icon,
    required Color color,
    bool isTotal = false,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isTotal ? 16 : 14,
                    fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                    color: const Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${earnings.toStringAsFixed(2)} ${isArabic ? 'ج.م' : 'EGP'}',
                      style: TextStyle(
                        fontSize: isTotal ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $deliveries ${isArabic ? 'توصيلة' : 'deliveries'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnpaidCommissionsCard({
    required BuildContext context,
    required int count,
    required num totalAmount,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF44336).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF44336).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF44336).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFF44336),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'العمولات غير المدفوعة' : 'Unpaid Commissions',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${totalAmount.toStringAsFixed(2)} ${isArabic ? 'ج.م' : 'EGP'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF44336),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $count ${isArabic ? 'عملية' : 'transactions'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}