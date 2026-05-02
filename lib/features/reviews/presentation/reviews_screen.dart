import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/reviews/presentation/widgets/review_card.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/circel_back_button.dart';
import '../manager/reviews_cubit.dart';
import '../manager/reviews_states.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isFetchingMore = false;

  @override
  void initState() {
    super.initState();
    context.read<ReviewsCubit>().fetchReviews();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_isFetchingMore) return;

    final state = context.read<ReviewsCubit>().state;
    if (state is! ReviewsLoaded || !state.hasMore) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _isFetchingMore = true;
      context.read<ReviewsCubit>().fetchMore().whenComplete(() {
        if (mounted) setState(() => _isFetchingMore = false);
      });
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
          leading: CircleBackButton(),
          title: Text(l10n.reviews, style: AppTextStyles.bold18),
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
}
