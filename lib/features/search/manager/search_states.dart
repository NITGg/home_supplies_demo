import '../data/models/search_models.dart';

sealed class SearchState {}

final class SearchInitial extends SearchState {}

final class SearchLoading extends SearchState {}

final class SearchSuccess extends SearchState {
  final SearchResponse result;
  SearchSuccess(this.result);
}

final class SearchEmpty extends SearchState {}

final class SearchError extends SearchState {
  final String message;
  SearchError(this.message);
}