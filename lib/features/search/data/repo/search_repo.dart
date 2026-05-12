// search_repository.dart

import '../../../../core/utils/logger.dart';
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
      dLog('[SearchRepository] error: $e $st');
      rethrow;
    }
  }
}