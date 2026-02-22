import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/reviews/manager/reviews_states.dart';
import '../../../core/utils/extract_error_message.dart';
import '../data/models/reviews_model.dart';
import '../data/repositories/reviews_repo.dart';

class ReviewsCubit extends Cubit<ReviewsState> {
  final ReviewsRepository _repository;

  ReviewsCubit(this._repository) : super(ReviewsInitial());

  List<ReviewModel> _reviews = [];
  int _currentPage = 1;
  static const int _limit = 20;
  bool _isFetchingMore = false;

  Future<void> fetchReviews() async {
    emit(ReviewsLoading());
    _reviews = [];
    _currentPage = 0;

    try {
      final response = await _repository.getMyReviews(
        skip: _currentPage,
        limit: _limit,
      );
      _reviews = response.reviews;
      emit(ReviewsLoaded(
        reviews: List.unmodifiable(_reviews),
        totalReviews: response.totalReviews,
        totalPages: response.totalPages,
        hasMore: _currentPage < response.totalPages,
      ));
    } catch (e) {
      emit(ReviewsFailure(extractErrorMessage(e)));
    }
  }

  Future<void> fetchMore() async {
    if (_isFetchingMore) return;
    final current = state;
    if (current is! ReviewsLoaded || !current.hasMore) return;

    _isFetchingMore = true;
    _currentPage++;

    try {
      final response = await _repository.getMyReviews(
        skip: _currentPage,
        limit: _limit,
      );
      _reviews.addAll(response.reviews);
      emit(ReviewsLoaded(
        reviews: List.unmodifiable(_reviews),
        totalReviews: response.totalReviews,
        totalPages: response.totalPages,
        hasMore: _currentPage < response.totalPages,
      ));
    } catch (e) {
      _currentPage--;
      log('Fetch more reviews error: $e');
    } finally {
      _isFetchingMore = false;
    }
  }
}