import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/core/style/app_colors.dart';
import '../../../core/widgets/circel_back_button.dart';
import '../../../l10n/manager/locale_cubit.dart';
import '../manager/points_cubit.dart';
import '../manager/points_states.dart';
import '../data/models/points_models.dart';

class PointsScreen extends StatelessWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = LocaleManager.currentLocale == 'ar';
    return BlocProvider(
      create: (context) => PointsCubit()..loadPoints(isArabic: isArabic),
      child: _PointsView(),
    );
  }
}

class _PointsView extends StatelessWidget {
  const _PointsView();

  @override
  Widget build(BuildContext context) {
    final isArabic = LocaleManager.currentLocale == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          isArabic ? 'نقاطي' : 'My Points',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: CircleBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/mainHome'),
        ),
      ),
      body: BlocBuilder<PointsCubit, PointsState>(
        builder: (context, state) {
          if (state is PointsLoading || state is PointsInitial) {
            return const _PointsShimmer();
          }

          if (state is PointsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<PointsCubit>().loadPoints(
                      isArabic: isArabic,
                    ),
                    child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is PointsLoaded) {
            return RefreshIndicator(
              onRefresh: () =>
                  context.read<PointsCubit>().loadPoints(isArabic: isArabic),
              color: AppColors.kPrimaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // ── Quick Actions ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.percent_rounded,
                              label: isArabic
                                  ? 'سداد العمولات'
                                  : 'Pay Commissions',
                              color: Colors.green.shade600,
                              onTap: () =>
                                  context.push('/wallet/unpaid-commissions'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.warning_amber_outlined,
                              label: isArabic
                                  ? 'سداد الغرامات'
                                  : 'Pay Penalties',
                              color: const Color(0xFFE17055),
                              onTap: () => context.push('/wallet/penalties'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Progress Section ──
                    _ProgressSection(
                      batch: state.progress.progress.ordersBatch,
                      pendingBatchBalance: state.progress.pendingBatchBalance,
                      // 👈
                      isArabic: isArabic,
                    ),

                    // ── Upcoming Expiration ──
                    if (state.progress.upcomingExpiration != null) ...[
                      const SizedBox(height: 16),
                      _ExpirationBanner(
                        expiration: state.progress.upcomingExpiration!,
                        isArabic: isArabic,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Rules Section ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        isArabic ? 'كيف تعمل النقاط؟' : 'How Points Work',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RuleCard(
                      icon: Icons.local_shipping_rounded,
                      color: Colors.blue.shade600,
                      title: isArabic ? 'كيف تكسب النقاط' : 'How to Earn',
                      description: state.localizedRules.ordersReward,
                    ),
                    _RuleCard(
                      icon: Icons.monetization_on_rounded,
                      color: Colors.green.shade600,
                      title: isArabic ? 'قيمة النقاط' : 'Points Value',
                      description: state.localizedRules.pointsValue,
                    ),
                    _RuleCard(
                      icon: Icons.timer_rounded,
                      color: Colors.orange.shade600,
                      title: isArabic ? 'انتهاء الصلاحية' : 'Expiration',
                      description: state.localizedRules.expiration,
                    ),
                    _RuleCard(
                      icon: Icons.redeem_rounded,
                      color: AppColors.kPrimaryColor,
                      title: isArabic ? 'استخدام النقاط' : 'Redeem Points',
                      description: state.localizedRules.redemption,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─── Progress Section ─────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final OrdersBatch batch;
  final int pendingBatchBalance; // 👈
  final bool isArabic;

  const _ProgressSection({
    required this.batch,
    required this.pendingBatchBalance, // 👈
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
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
          // ── Header row ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'تقدمك نحو المكافأة' : 'Progress to Next Reward',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${batch.ordersCompletedInCurrentBatch} / ${batch.requiredOrdersForNextBatch}',
                  style: TextStyle(
                    color: AppColors.kPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Progress bar ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: batch.progressFraction,
              minHeight: 12,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.kPrimaryColor,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Step dots ─────────────────────────────────────────────────
          Row(
            children: List.generate(batch.requiredOrdersForNextBatch, (index) {
              final isCompleted = index < batch.ordersCompletedInCurrentBatch;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.kPrimaryColor
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 12),

          // ── Remaining orders hint ─────────────────────────────────────
          if (batch.remainingOrders > 0)
            Text(
              isArabic
                  ? 'متبقي ${batch.remainingOrders} طلب لإتمام الدفعة'
                  : '${batch.remainingOrders} more ${batch.remainingOrders == 1 ? 'order' : 'orders'} to complete this batch',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            )
          else
            Text(
              isArabic ? '🎉 لقد أكملت الدفعة!' : '🎉 Batch complete!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),

          // ── Pending batch balance ─────────────────────────────────────
          if (pendingBatchBalance > 0) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lock_clock_rounded,
                    size: 18,
                    color: Colors.amber.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'نقاط قيد الإتمام' : 'Pending Points',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? 'ستُفتح عند إتمام الدفعة'
                            : 'Unlocks when you complete this batch',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    '$pendingBatchBalance ${isArabic ? 'نقطة' : 'pts'}',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Expiration Banner ────────────────────────────────────────────────────────

class _ExpirationBanner extends StatelessWidget {
  final UpcomingExpiration expiration;
  final bool isArabic;

  const _ExpirationBanner({required this.expiration, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final daysLeft = expiration.expiresAt.difference(DateTime.now()).inDays;

    return daysLeft >= 2
        ? SizedBox.shrink()
        : Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic
                            ? 'نقاط على وشك الانتهاء'
                            : 'Points Expiring Soon',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? '${expiration.points} نقطة ستنتهي خلال $daysLeft يوم'
                            : '${expiration.points} points expire in $daysLeft days',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 13,
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
// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rule Card ────────────────────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _RuleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.5,
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

// ─── Shimmer Loading ──────────────────────────────────────────────────────────

class _PointsShimmer extends StatefulWidget {
  const _PointsShimmer();

  @override
  State<_PointsShimmer> createState() => _PointsShimmerState();
}

class _PointsShimmerState extends State<_PointsShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.9).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _shimmerBox({double height = 16, double? width, double radius = 8}) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(_animation.value),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Action buttons shimmer
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress card shimmer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(height: 16, width: 200),
                const SizedBox(height: 16),
                _shimmerBox(height: 12, radius: 8),
                const SizedBox(height: 12),
                _shimmerBox(height: 6, radius: 3),
                const SizedBox(height: 14),
                _shimmerBox(height: 14, width: 180),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Rules shimmer
          ...List.generate(
            4,
            (i) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(height: 42, width: 42, radius: 10),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBox(height: 14, width: 100),
                        const SizedBox(height: 8),
                        _shimmerBox(height: 12),
                        const SizedBox(height: 4),
                        _shimmerBox(height: 12, width: double.infinity * 0.7),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
