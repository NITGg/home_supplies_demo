import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/style/app_colors.dart';
import '../../../l10n/app_localizations.dart';
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
      child: const _PointsView(),
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
        leading: BackButton(
          color: Colors.black,
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
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 12),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<PointsCubit>().loadPoints(isArabic: isArabic),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kPrimaryColor,
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
                    // ── Balance Header Card ──
                    _PointsBalanceCard(
                      balance: state.progress.balance,
                      isArabic: isArabic,
                    ),

                    const SizedBox(height: 20),

                    // ── Progress Section ──
                    _ProgressSection(
                      batch: state.progress.progress.ordersBatch,
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

// ─── Balance Card ────────────────────────────────────────────────────────────

class _PointsBalanceCard extends StatelessWidget {
  final PointsBalance balance;
  final bool isArabic;

  const _PointsBalanceCard({required this.balance, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.kPrimaryColor, AppColors.kPrimaryColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.kPrimaryColor.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Text(
                isArabic ? 'رصيد النقاط' : 'Points Balance',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${balance.availablePoints}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isArabic ? 'نقطة' : 'points',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isArabic
                  ? '≈ ${balance.monetaryValueEgp.toStringAsFixed(2)} جنيه'
                  : '≈ ${balance.monetaryValueEgp.toStringAsFixed(2)} EGP',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Progress Section ─────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final OrdersBatch batch;
  final bool isArabic;

  const _ProgressSection({required this.batch, required this.isArabic});

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'تقدمك نحو النقاط' : 'Progress to Next Reward',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${batch.currentOrder} / ${batch.requiredOrders}',
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

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: batch.progressPercentage,
              minHeight: 12,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.kPrimaryColor),
            ),
          ),

          const SizedBox(height: 12),

          // Order icons row
          Row(
            children: List.generate(batch.requiredOrders, (index) {
              final isCompleted = index < batch.currentOrder;
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

          const SizedBox(height: 14),

          Text(
            batch.remainingOrders == 0
                ? (isArabic ? '🎉 لقد حققت المكافأة!' : '🎉 You\'ve earned the reward!')
                : isArabic
                ? 'متبقي ${batch.remainingOrders} طلبات للحصول على 50 نقطة'
                : '${batch.remainingOrders} more orders to earn 50 points',
            style: TextStyle(
              color: batch.remainingOrders == 0
                  ? Colors.green.shade600
                  : Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'نقاط على وشك الانتهاء' : 'Points Expiring Soon',
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
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
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
          // Balance card shimmer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(height: 48, width: 48, radius: 12),
                const SizedBox(height: 20),
                _shimmerBox(height: 52, width: 120),
                const SizedBox(height: 8),
                _shimmerBox(height: 16, width: 60),
                const SizedBox(height: 16),
                _shimmerBox(height: 36, width: 160, radius: 10),
              ],
            ),
          ),
          const SizedBox(height: 20),
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