import 'package:equatable/equatable.dart';
import '../data/models/reviews_model.dart';

abstract class ReviewsState extends Equatable {
  const ReviewsState();

  @override
  List<Object?> get props => [];
}

class ReviewsInitial extends ReviewsState {
  const ReviewsInitial();
}

class ReviewsLoading extends ReviewsState {
  const ReviewsLoading();
}

class ReviewsLoaded extends ReviewsState {
  final List<ReviewModel> reviews;
  final int totalReviews;
  final int totalPages;
  final bool hasMore;

  const ReviewsLoaded({
    required this.reviews,
    required this.totalReviews,
    required this.totalPages,
    required this.hasMore,
  });

  @override
  List<Object?> get props => [reviews, totalReviews, totalPages, hasMore];
}

class ReviewsFailure extends ReviewsState {
  final String message;
  const ReviewsFailure(this.message);

  @override
  List<Object?> get props => [message];
}
