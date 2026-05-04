import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/widgets/circel_back_button.dart';
import 'package:tawreedat_go/features/auth/manager/profile_cubit.dart';
import '../../../core/style/app_colors.dart';
import '../../../l10n/manager/locale_cubit.dart';
import '../../wallet/manager/wallet_cubit.dart';
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
    final balance =
        context.watch<WalletCubit>().cachedWalletData?.wallet.points.toDouble() ?? 0.0;
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
      body: BlocConsumer<PointsCubit, PointsState>(
        listener: (context, state) {
          if (state is PointsConverted) {
            context.read<WalletCubit>().refreshWalletData();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isArabic
                      ? '✅ تم تحويل ${state.pointsConverted} نقطة إلى رصيد بنجاح!'
                      : '✅ ${state.pointsConverted} points converted successfully!',
                ),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is FinesPaidWithPoints) {
            // Also refresh after paying fines
            context.read<WalletCubit>().refreshWalletData(); }
          else if (state is ConvertPointsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
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

          if (state is PointsLoaded ||
              state is ConvertingPoints ||
              state is ConvertPointsError ||
              state is PointsConverted) {
            // Preserve loaded data even during converting states
            final cubit = context.read<PointsCubit>();
            final loadedState = state is PointsLoaded
                ? state
                : null; // fallback handled below

            return RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  context.read<PointsCubit>().loadPoints(isArabic: isArabic),
                  context.read<WalletCubit>().refreshWalletData(),  // ← add this
                ]);
              },
              color: AppColors.kPrimaryColor,
              child: BlocBuilder<PointsCubit, PointsState>(
                builder: (context, innerState) {
                  if (innerState is! PointsLoaded) {
                    return const _PointsShimmer();
                  }
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
// ── Balance Card ───────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            width: double.infinity,
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
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.stars_rounded, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      isArabic ? 'رصيد النقاط' : 'Points Balance',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  balance.toInt().toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isArabic ? 'نقطة' : 'points',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        isArabic
                                            ? '≈ ${(balance / 10).toStringAsFixed(2)} جنيه'
                                            : '≈ ${(balance / 10).toStringAsFixed(2)} EGP',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        // ── Quick Actions ──────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.account_balance_wallet_rounded,
                                  label: isArabic
                                      ? 'تحويل إلى رصيد'
                                      : 'Convert to Money',
                                  color: Colors.green.shade600,
                                  onTap: () => _showConvertBottomSheet(
                                    context,
                                    balance,
                                    isArabic,
                                  ),
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
                                  onTap: () =>
                                      context.push('/wallet/penalties'),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Progress Section ──
                        // _ProgressSection(
                        //   batch: innerState.progress.progress.ordersBatch,
                        //   isArabic: isArabic,
                        // ),

                        // ── Upcoming Expiration ──
                        if (innerState.progress.upcomingExpiration != null) ...[
                          const SizedBox(height: 16),
                          _ExpirationBanner(
                            expiration: innerState.progress.upcomingExpiration!,
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
                          description: innerState.localizedRules.ordersReward,
                        ),
                        _RuleCard(
                          icon: Icons.monetization_on_rounded,
                          color: Colors.green.shade600,
                          title: isArabic ? 'قيمة النقاط' : 'Points Value',
                          description: innerState.localizedRules.pointsValue,
                        ),
                        _RuleCard(
                          icon: Icons.timer_rounded,
                          color: Colors.orange.shade600,
                          title: isArabic ? 'انتهاء الصلاحية' : 'Expiration',
                          description: innerState.localizedRules.expiration,
                        ),
                        _RuleCard(
                          icon: Icons.redeem_rounded,
                          color: AppColors.kPrimaryColor,
                          title: isArabic ? 'استخدام النقاط' : 'Redeem Points',
                          description: innerState.localizedRules.redemption,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showConvertBottomSheet(
    BuildContext context,
    double balance,
    bool isArabic,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<PointsCubit>(),
        child: _ConvertBottomSheet(
          availablePoints: balance.toInt(),
          monetaryValueEgp: balance.toInt() / 10,
          isArabic: isArabic,
        ),
      ),
    );
  }
}

// ─── Convert to Money Bottom Sheet ───────────────────────────────────────────

class _ConvertBottomSheet extends StatefulWidget {
  final int availablePoints;
  final double monetaryValueEgp;
  final bool isArabic;

  const _ConvertBottomSheet({
    required this.availablePoints,
    required this.monetaryValueEgp,
    required this.isArabic,
  });

  @override
  State<_ConvertBottomSheet> createState() => _ConvertBottomSheetState();
}

class _ConvertBottomSheetState extends State<_ConvertBottomSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  double get _ratePerPoint => widget.availablePoints > 0
      ? widget.monetaryValueEgp / widget.availablePoints
      : 0;

  double get _previewEgp {
    final pts = int.tryParse(_controller.text) ?? 0;
    return pts * _ratePerPoint;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.isArabic;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              isArabic ? 'تحويل النقاط إلى رصيد' : 'Convert Points to Money',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic
                  ? 'رصيدك: ${widget.availablePoints} نقطة ≈ ${widget.monetaryValueEgp.toStringAsFixed(2)} جنيه'
                  : 'Balance: ${widget.availablePoints} pts ≈ ${widget.monetaryValueEgp.toStringAsFixed(2)} EGP',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // Points input
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: isArabic
                    ? 'عدد النقاط للتحويل'
                    : 'Points to convert',
                hintText: isArabic
                    ? 'الحد الأقصى: ${widget.availablePoints}'
                    : 'Max: ${widget.availablePoints}',
                prefixIcon: const Icon(Icons.stars_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.kPrimaryColor,
                    width: 2,
                  ),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return isArabic ? 'أدخل عدد النقاط' : 'Enter points amount';
                }
                final pts = int.tryParse(val);
                if (pts == null || pts <= 0) {
                  return isArabic ? 'قيمة غير صالحة' : 'Invalid value';
                }
                if (pts > widget.availablePoints) {
                  return isArabic
                      ? 'تجاوزت الرصيد المتاح'
                      : 'Exceeds your available balance';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Live preview
            if (_controller.text.isNotEmpty &&
                (int.tryParse(_controller.text) ?? 0) > 0)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'ستحصل على ≈ ${_previewEgp.toStringAsFixed(2)} جنيه'
                            : 'You\'ll receive ≈ ${_previewEgp.toStringAsFixed(2)} EGP',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Submit button
            BlocBuilder<PointsCubit, PointsState>(
              builder: (context, state) {
                final isLoading = state is ConvertingPoints;
                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              context.read<PointsCubit>().convertPointsToMoney(
                                points: int.parse(_controller.text),
                                isArabic: isArabic,
                                userId:
                                    context
                                        .read<ProfileCubit>()
                                        .currentProfile
                                        ?.id ??
                                    1,
                              );
                              Navigator.pop(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isArabic ? 'تحويل الآن' : 'Convert Now',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: batch.progressPercentage,
              minHeight: 12,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.kPrimaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
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
          Container(
            width: double.infinity,
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 20),
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
