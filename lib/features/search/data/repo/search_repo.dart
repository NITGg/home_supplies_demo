// search_repository.dart

import 'dart:developer';
import '../data_source/search_remote_data_source.dart';
import '../models/search_models.dart';


abstract class SearchRepository {
  Future<SearchResponse> search(String query);
}

class SearchRepositoryImpl implements SearchRepository {
  final SearchDataSource _dataSource;

  SearchRepositoryImpl(this._dataSource);

  @override
  Future<SearchResponse> search(String query) async {
    try {
      return await _dataSource.search(query);
    } catch (e, st) {
      log('[SearchRepository] error: $e', stackTrace: st);
      rethrow;
    }
  }
}