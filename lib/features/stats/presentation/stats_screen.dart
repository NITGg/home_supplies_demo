import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/features/stats/presentation/widgets/date_range_selector.dart';
import 'package:tawreedat_courier/features/stats/presentation/widgets/stats_skeletons.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/banners.dart';
import '../../stats/manager/stats_cubit.dart';
import '../../stats/manager/stats_states.dart';
import '../../stats/presentation/widgets/badge_progress_section.dart';
import '../../stats/presentation/widgets/earnings_summary_section.dart';
import '../../stats/presentation/widgets/performance_section.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String? _startDate;
  String? _endDate;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (context.mounted) {
        _fetchAll();
      }
    });
  }

  void _fetchAll() {
    context.read<StatsCubit>().fetchBadgeProgress();
    context.read<StatsCubit>().fetchAllStats(
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  void _onDateRangeChanged(
    String? startDate,
    String? endDate,
    DateRangePreset preset,
  ) {
    // ← add preset
    setState(() {
      _startDate = startDate;
      _endDate = endDate;
    });
    context.read<StatsCubit>().fetchAllStats(
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: BlocListener<StatsCubit, StatsState>(
          listener: (context, state) {
            if (state is StatsFailure) {
              showErrorBanner(context, state.message);
            }
          },
          child: BlocBuilder<StatsCubit, StatsState>(
            builder: (context, state) {
              final cubit = context.read<StatsCubit>();

              // ── Hard error with no cached data at all ───────────────
              if (state is StatsFailure &&
                  cubit.badgeProgress == null &&
                  cubit.earningsSummary == null &&
                  cubit.performance == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(localizations.error),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchAll,
                        child: Text(localizations.retry),
                      ),
                    ],
                  ),
                );
              }

              final badgeProgress = cubit.badgeProgress;
              final earningsSummary = cubit.earningsSummary;
              final performance = cubit.performance;

              return RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    context.read<StatsCubit>().fetchBadgeProgress(),
                    context.read<StatsCubit>().fetchAllStats(
                      startDate: _startDate,
                      endDate: _endDate,
                    ),
                  ]);
                },
                color: AppColors.kPrimaryColor,
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    // ── Badge Progress ──────────────────────────────────
                    SliverToBoxAdapter(
                      child:
                          (state is BadgeProgressLoading &&
                              badgeProgress == null)
                          ? const BadgeProgressSkeleton()
                          : badgeProgress != null
                          ? BadgeProgressSection(badgeProgress: badgeProgress)
                          : const SizedBox.shrink(),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    // ── Earnings Summary ────────────────────────────────
                    SliverToBoxAdapter(
                      child:
                          (state is EarningsSummaryLoading &&
                              earningsSummary == null)
                          ? const EarningsSummarySkeleton()
                          : earningsSummary != null
                          ? EarningsSummarySection(
                              earningsSummary: earningsSummary,
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    // ── Performance ─────────────────────────────────────
                    SliverToBoxAdapter(
                      child:
                          (state is PerformanceLoading && performance == null)
                          ? const PerformanceSkeleton()
                          : performance != null
                          ? PerformanceSection(
                              performance: performance,
                              onDateRangeChanged: _onDateRangeChanged,
                              isArabic: isArabic,
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
