import 'package:dio/dio.dart';
import 'package:tawreedat_courier/core/utils/api_client.dart';
import 'models/delivery_areas_models.dart';
import 'dart:developer';

class DeliveryAreasService {
  final ApiClient _apiClient = ApiClient.instance;

  /// Get courier's currently selected delivery areas
  Future<List<SelectedArea>> getSelectedAreas() async {
    try {
      final response = await _apiClient.dio.get(
        '/profile/get-selected-areas',
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        final areasList = data['areas'] as List<dynamic>;

        return areasList
            .map((json) => SelectedArea.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load selected areas');
      }
    } on DioException catch (e) {
      log('Error getting selected areas: ${e.message}');
      rethrow;
    }
  }

  /// Get all available governorates
  Future<List<Governorate>> getGovernorates() async {
    try {
      final response = await _apiClient.dio.get(
        '/profile/locations/governorates',
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        final governoratesList = data['governorates'] as List<dynamic>;

        return governoratesList
            .map((json) => Governorate.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load governorates');
      }
    } on DioException catch (e) {
      log('Error getting governorates: ${e.message}');
      rethrow;
    }
  }

  /// Get areas for a specific governorate
  Future<Map<String, dynamic>> getAreasByGovernorate(int governorateId) async {
    try {
      final response = await _apiClient.dio.get(
        '/profile/locations/governorates/$governorateId/areas',
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;

        final governorate = Governorate.fromJson(
          data['governorate'] as Map<String, dynamic>,
        );

        final areasList = data['areas'] as List<dynamic>;
        final areas = areasList
            .map((json) => Area.fromJson(json as Map<String, dynamic>))
            .toList();

        return {
          'governorate': governorate,
          'areas': areas,
        };
      } else {
        throw Exception('Failed to load areas');
      }
    } on DioException catch (e) {
      log('Error getting areas for governorate $governorateId: ${e.message}');
      rethrow;
    }
  }

  /// Update courier's selected delivery areas
  Future<List<SelectedArea>> updateSelectedAreas(
      List<AreaSelectionRequest> selectedAreas,
      ) async {
    try {
      final response = await _apiClient.dio.patch(
        '/profile/update-selected-areas',
        data: {
          'areas': selectedAreas.map((area) => area.toJson()).toList(),
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        final areasList = data['areas'] as List<dynamic>;

        return areasList
            .map((json) => SelectedArea.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to update selected areas');
      }
    } on DioException catch (e) {
      log('Error updating selected areas: ${e.message}');
      rethrow;
    }
  }
}