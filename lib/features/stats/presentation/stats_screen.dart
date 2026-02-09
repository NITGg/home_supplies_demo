import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/widgets/loading_screen.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../auth/manager/profile_cubit.dart';
import '../../auth/manager/profile_states.dart';
import '../../auth/presentation/widgets/profile_badge_section.dart';
import '../../stats/manager/stats_cubit.dart';
import '../../stats/manager/stats_states.dart';
import '../../stats/presentation/widgets/earnings_summary_section.dart';
import '../../stats/presentation/widgets/performance_section.dart';
import '../../stats/presentation/widgets/date_range_selector.dart';

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
    // Fetch all required data on init
    Future.microtask(() {
      if (context.mounted) {
        context.read<ProfileCubit>().fetchProfile();
        context.read<ProfileCubit>().fetchBadgeProgress();
        _fetchStats();
      }
    });
  }

  void _fetchStats() {
    context.read<StatsCubit>().fetchAllStats(
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  void _onDateRangeChanged(String? startDate, String? endDate) {
    setState(() {
      _startDate = startDate;
      _endDate = endDate;
    });
    _fetchStats();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: MultiBlocListener(
          listeners: [
            BlocListener<ProfileCubit, ProfileState>(
              listener: (context, state) {
                if (state is ProfileFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            BlocListener<StatsCubit, StatsState>(
              listener: (context, state) {
                if (state is StatsFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
          child: BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, profileState) {
              final profile = context.read<ProfileCubit>().currentProfile;
              final badgeProgress = context.read<ProfileCubit>().badgeProgress;

              // Show loading only when initially loading profile
              if (profileState is ProfileLoading && profile == null) {
                return const Center(child: LoadingScreen(isOne: true));
              }

              // Show error state if profile failed to load
              if (profile == null) {
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
                        onPressed: () {
                          context.read<ProfileCubit>().fetchProfile();
                          context.read<ProfileCubit>().fetchBadgeProgress();
                          _fetchStats();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kPrimaryColor,
                        ),
                        child: Text(localizations.retry),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    context.read<ProfileCubit>().fetchProfile(),
                    context.read<ProfileCubit>().fetchBadgeProgress(),
                    context.read<StatsCubit>().fetchAllStats(
                      startDate: _startDate,
                      endDate: _endDate,
                    ),
                  ]);
                },
                color: AppColors.kPrimaryColor,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 24),

                          // Badge Progress Section (existing)
                          if (badgeProgress != null)
                            BadgeProgressSection(badgeProgress: badgeProgress),

                          const SizedBox(height: 24),

                          // Earnings Summary Section
                          BlocBuilder<StatsCubit, StatsState>(
                            builder: (context, state) {
                              final earningsSummary =
                                  context.read<StatsCubit>().earningsSummary;

                              if (state is EarningsSummaryLoading &&
                                  earningsSummary == null) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (earningsSummary != null) {
                                return EarningsSummarySection(
                                  earningsSummary: earningsSummary,
                                );
                              }

                              return const SizedBox.shrink();
                            },
                          ),

                          const SizedBox(height: 24),

                          // Performance Section
                          BlocBuilder<StatsCubit, StatsState>(
                            builder: (context, state) {
                              final performance =
                                  context.read<StatsCubit>().performance;

                              if (state is PerformanceLoading &&
                                  performance == null) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (performance != null) {
                                return Column(
                                  children: [
                                    PerformanceSection(
                                      performance: performance,
                                    ),
                                    // Show selected date range if custom
                                    if (_startDate != null ||
                                        _endDate != null) ...[
                                      const SizedBox(height: 12),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(
                                          '${isArabic ? 'الفترة' : 'Period'}: ${performance.dateRange.startDate} ${isArabic ? 'إلى' : 'to'} ${performance.dateRange.endDate}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF666666),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }

                              return const SizedBox.shrink();
                            },
                          ),
                          const SizedBox(height: 24),

                          // Date Range Selector
                          DateRangeSelector(
                            onDateRangeChanged: _onDateRangeChanged,
                            isArabic: isArabic,
                          ),

                          const SizedBox(height: 24),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
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