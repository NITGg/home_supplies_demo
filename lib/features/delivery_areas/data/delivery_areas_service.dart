import 'package:tawreedat_courier/core/utils/api_client.dart';
import '../../../l10n/manager/locale_cubit.dart';
import 'models/delivery_areas_models.dart';

class DeliveryAreasService {
  final ApiClient _apiClient = ApiClient.instance;

  /// Get courier's currently selected delivery areas
  Future<List<SelectedArea>> getSelectedAreas() async {
      final response = await _apiClient.dio.get(
        '/profile/get-selected-areas?lang=${LocaleManager.currentLocale}',
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

  }

  /// Get all available governorates
  Future<List<Governorate>> getGovernorates() async {
      final response = await _apiClient.dio.get(
        '/profile/locations/governorates?lang=${LocaleManager.currentLocale}',
        data:
          {
            "is_active": true
          }
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

  }

  /// Get areas for a specific governorate
  Future<Map<String, dynamic>> getAreasByGovernorate(int governorateId) async {
      final response = await _apiClient.dio.get(
        '/profile/locations/governorates/$governorateId/areas?lang=${LocaleManager.currentLocale}',
          data:
          {
            "is_active": true
          }
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

  }

  /// Update courier's selected delivery areas
  Future<List<SelectedArea>> updateSelectedAreas(
      List<AreaSelectionRequest> selectedAreas,
      ) async {
      final response = await _apiClient.dio.patch(
        '/profile/update-selected-areas?lang=${LocaleManager.currentLocale}',
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

  }
}