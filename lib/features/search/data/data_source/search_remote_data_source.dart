// search_datasource.dart

import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/location_service.dart';
import '../../../../core/utils/logger.dart';
import '../models/search_models.dart';

abstract class SearchDataSource {
  Future<SearchResponse> search(String query);
}

class SearchRemoteDataSource implements SearchDataSource {
  final Dio _dio = ApiClient.instance.dio;

  @override
  Future<SearchResponse> search(String query) async {
    dLog('[Search] query: "$query"');
    final response = await _dio.get(
      '/search',
      queryParameters: {'q': query},
      data: LocationService.instance.latLngBody,
    );
    dLog('[Search] response: ${response.statusCode}');
    dLog('[Search] response: ${response.data}');
    return SearchResponse.fromJson(response.data as Map<String, dynamic>);
  }
}