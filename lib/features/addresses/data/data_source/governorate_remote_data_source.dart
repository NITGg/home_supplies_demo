import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/governorate_model.dart';

class GovernorateRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<GovernoratesResponse> getGovernoratesWithAreas() async {
    final response = await _dio.get('/governorates?includes=areas');
    if (response.statusCode == 200) {
      return GovernoratesResponse.fromJson(response.data);
    }
    throw Exception('Failed to load governorates');
  }
}