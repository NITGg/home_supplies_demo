// search_cubit.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/search_models.dart';
import '../data/repo/search_repo.dart';
import 'search_states.dart';


class SearchCubit extends Cubit<SearchState> {
  final SearchRepository _repository;
  Timer? _debounce;

  /// Keeps the last successful response so category-filter changes can
  /// re-emit without re-fetching from the network.
  SearchResponse? _lastResult;

  SearchCubit(this._repository) : super(SearchInitial());

  // ── Query ──────────────────────────────────────────────────────────────────

  /// Called on every keystroke — debounces 400 ms before firing the request.
  void onQueryChanged(String query) {
    _debounce?.cancel();
    _lastResult = null;

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      emit(SearchInitial());
      return;
    }

    emit(SearchLoading());

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result = await _repository.search(trimmed);
        if (isClosed) return;
        _lastResult = result;
        result.isEmpty ? emit(SearchEmpty()) : emit(SearchSuccess(result));
      } catch (e) {
        if (isClosed) return;
        emit(SearchError(e.toString()));
      }
    });
  }

  // ── Category filter ────────────────────────────────────────────────────────

  /// Select (or deselect when [categoryId] is null) a category filter.
  /// Does nothing if there is no live result yet.
  void selectCategory(int? categoryId) {
    final result = _lastResult;
    if (result == null) return;
    if (isClosed) return;
    emit(SearchSuccess(result, selectedCategoryId: categoryId));
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  void reset() {
    _debounce?.cancel();
    _lastResult = null;
    emit(SearchInitial());
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
