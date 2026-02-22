import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/reviews/presentation/widgets/review_card.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../manager/reviews_cubit.dart';
import '../manager/reviews_states.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<ReviewsCubit>().fetchReviews();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ReviewsCubit>().fetchMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.kBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          leading: BackButton(
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(
            l10n.reviews,
            style: AppTextStyles.bold18,
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<ReviewsCubit, ReviewsState>(
          builder: (context, state) {
            if (state is ReviewsLoading) {
              return const Center(child: LoadingScreen(isOne: true));
            }

            if (state is ReviewsFailure) {
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
                    Text(
                      state.message,
                      style: AppTextStyles.regular14.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<ReviewsCubit>().fetchReviews(),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              );
            }

            if (state is ReviewsLoaded) {
              if (state.reviews.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star_border_rounded,
                        size: 80,
                        color: AppColors.kPrimaryColor.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noData,
                        style: AppTextStyles.bold18.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Summary header
                  _buildSummaryHeader(context, state),

                  // Reviews list
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.kPrimaryColor,
                      onRefresh: () =>
                          context.read<ReviewsCubit>().fetchReviews(),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            state.reviews.length + (state.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.reviews.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.kPrimaryColor,
                                ),
                              ),
                            );
                          }
                          return ReviewCard(review: state.reviews[index]);
                        },
                      ),
                    ),
                  ),
                ],
              );
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, ReviewsLoaded state) {
    final l10n = AppLocalizations.of(context)!;

    // Average rating
    final avg = state.reviews.isEmpty
        ? 0.0
        : state.reviews.map((r) => r.rating).reduce((a, b) => a + b) /
              state.reviews.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2D3436),
            Color(0xFF636E72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.kSecondaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Average score
          Expanded(
            child: Column(
              children: [
                Text(
                  avg.toStringAsFixed(1),
                  style: AppTextStyles.bold25.copyWith(
                    color: AppColors.kPrimaryColor,
                    fontSize: 40,
                  ),
                ),
                _buildStarRow(avg),
                const SizedBox(height: 4),
                Text(
                  '${state.totalReviews} ${l10n.totalReviews}',
                  style: AppTextStyles.regular14.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 60, color: Colors.white24),
          // Rating breakdown
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Column(
                children: [5, 4, 3, 2, 1].map((star) {
                  final count = state.reviews
                      .where((r) => r.rating == star)
                      .length;
                  final fraction = state.reviews.isEmpty
                      ? 0.0
                      : count / state.reviews.length;
                  return _buildRatingBar(star, fraction, count);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRow(double rating) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return const Icon(
            Icons.star_rounded,
            color: AppColors.kPrimaryColor,
            size: 18,
          );
        } else if (i < rating) {
          return const Icon(
            Icons.star_half_rounded,
            color: AppColors.kPrimaryColor,
            size: 18,
          );
        }
        return const Icon(
          Icons.star_border_rounded,
          color: Colors.white38,
          size: 18,
        );
      }),
    );
  }

  Widget _buildRatingBar(int star, double fraction, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Text(
            '$star',
            style: AppTextStyles.regular14.copyWith(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.star_rounded,
            color: AppColors.kPrimaryColor,
            size: 10,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(
                  AppColors.kPrimaryColor,
                ),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: AppTextStyles.regular14.copyWith(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
