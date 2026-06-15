
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/safe_emit_mixin.dart';
import '../data/repo/category_repo.dart';
import 'category_states.dart';

class CategoriesCubit extends Cubit<CategoriesState> with SafeEmitMixin<CategoriesState> {
  final CategoryRepository _repository;

  static const int _pageSize = 10000;
  int _currentSkip = 0;

  CategoriesCubit({CategoryRepository? repository})
      : _repository = repository ?? CategoryRepositoryImpl(),
        super(const CategoriesInitial());

  Future<void> loadCategories({bool refresh = false}) async {
    if (refresh) {
      _currentSkip = 0;
      if (!isClosed) safeEmit(const CategoriesLoading());
    } else if (state is CategoriesLoading) {
      return;
    } else {
      if (!isClosed) safeEmit(const CategoriesLoading());
    }

    try {
      final response = await _repository.getCategories(
        skip: 0,
        limit: _pageSize,
      );

      _currentSkip = response.categories.length;

      if (!isClosed) {
        safeEmit(CategoriesLoaded(
          categories: response.categories,
          totalCount: response.totalCount,
          hasMore: _currentSkip < response.totalCount,
        ));
      }
    } catch (e) {
      dLog('CategoriesCubit: Error loading categories: $e');
      if (!isClosed) safeEmit(CategoriesError(extractErrorMessage(e)));
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! CategoriesLoaded || !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    if (!isClosed) safeEmit(current.copyWith(isLoadingMore: true));

    try {
      final response = await _repository.getCategories(
        skip: _currentSkip,
        limit: _pageSize,
      );

      _currentSkip += response.categories.length;

      if (!isClosed) {
        safeEmit(current.copyWith(
          categories: [...current.categories, ...response.categories],
          hasMore: _currentSkip < response.totalCount,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      dLog('CategoriesCubit: Error loading more categories: $e');
      if (!isClosed) safeEmit(current.copyWith(isLoadingMore: false));
    }
  }
}