
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/features/reviews/manager/reviews_states.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../data/models/reviews_model.dart';
import '../data/repositories/reviews_repo.dart';

class ReviewsCubit extends Cubit<ReviewsState> {
  final ReviewsRepository _repository;

  ReviewsCubit(this._repository) : super(ReviewsInitial());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed.
  @override
  void emit(ReviewsState state) {
    if (!isClosed) super.emit(state);
  }

  List<ReviewModel> _reviews = [];
  int _currentPage = 1;
  static const int _limit = 20;
  bool _isFetchingMore = false;

  Future<void> fetchReviews() async {
    emit(ReviewsLoading());
    _reviews = [];
    _currentPage = 1;

    try {
      final response = await _repository.getMyReviews(
        page: _currentPage,
        limit: _limit,
      );
      _reviews = response.reviews;
      emit(ReviewsLoaded(
        reviews: List.unmodifiable(_reviews),
        totalReviews: response.totalReviews,
        totalPages: response.totalPages,
        hasMore: response.hasNext, // ← use hasNext from API directly
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
        page: _currentPage,
        limit: _limit,
      );
      _reviews.addAll(response.reviews);
      emit(ReviewsLoaded(
        reviews: List.unmodifiable(_reviews),
        totalReviews: response.totalReviews,
        totalPages: response.totalPages,
        hasMore: response.hasNext,
      ));
    } catch (e) {
      _currentPage--;
      dLog('Fetch more error: $e');
    } finally {
      _isFetchingMore = false;
    }
  }
}