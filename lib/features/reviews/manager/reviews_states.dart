import '../data/models/reviews_model.dart';

abstract class ReviewsState {}

class ReviewsInitial extends ReviewsState {}

class ReviewsLoading extends ReviewsState {}

class ReviewsLoaded extends ReviewsState {
  final List<ReviewModel> reviews;
  final int totalReviews;
  final int totalPages;
  final bool hasMore;

  ReviewsLoaded({
    required this.reviews,
    required this.totalReviews,
    required this.totalPages,
    required this.hasMore,
  });
}

class ReviewsFailure extends ReviewsState {
  final String message;
  ReviewsFailure(this.message);
}