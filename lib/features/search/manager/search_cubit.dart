// search_cubit.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/search/manager/search_states.dart';

import '../data/repo/search_repo.dart';


class SearchCubit extends Cubit<SearchState> {
  final SearchRepository _repository;
  Timer? _debounce;

  SearchCubit(this._repository) : super(SearchInitial());

  /// Called on every keystroke — debounces 400 ms before firing the request.
  void onQueryChanged(String query) {
    _debounce?.cancel();

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
        result.isEmpty ? emit(SearchEmpty()) : emit(SearchSuccess(result));
      } catch (e) {
        if (isClosed) return;
        emit(SearchError(e.toString()));
      }
    });
  }

  void reset() {
    _debounce?.cancel();
    emit(SearchInitial());
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}