// search_datasource.dart

import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/search_models.dart';

abstract class SearchDataSource {
  Future<SearchResponse> search(String query);
}

class SearchRemoteDataSource implements SearchDataSource {
  final Dio _dio = ApiClient.instance.dio;

  @override
  Future<SearchResponse> search(String query) async {
    log('[Search] query: "$query"');
    final response = await _dio.get(
      '/search',
      queryParameters: {'q': query},
    );
    log('[Search] response: ${response.statusCode}');
    return SearchResponse.fromJson(response.data as Map<String, dynamic>);
  }
}