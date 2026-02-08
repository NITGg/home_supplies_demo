import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/widgets/loading_screen.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../auth/manager/profile_cubit.dart';
import '../../auth/manager/profile_states.dart';
import '../../auth/presentation/widgets/profile_badge_section.dart';
import '../../auth/presentation/widgets/profile_stats_card_section.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: BlocConsumer<ProfileCubit, ProfileState>(
          listener: (context, state) {
            if (state is ProfileFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
            if (state is ProfileUpdateSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is ProfileLoading &&
                context.read<ProfileCubit>().currentProfile == null) {
              return const Center(child: LoadingScreen(isOne: true));
            }

            final profile = context.read<ProfileCubit>().currentProfile;
            final badgeProgress = context.read<ProfileCubit>().badgeProgress;

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
                Future.wait([
                  context.read<ProfileCubit>().fetchProfile(),
                  context.read<ProfileCubit>().fetchBadgeProgress(),
                ]);
              },
              color: AppColors.kPrimaryColor,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        if (badgeProgress != null)
                          BadgeProgressSection(badgeProgress: badgeProgress),
                        const SizedBox(height: 24),
                        StatsCardsSection(stats: profile.courier.stat),
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
    );
  }
}
