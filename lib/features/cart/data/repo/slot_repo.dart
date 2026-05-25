import 'package:dio/dio.dart';
import 'package:tawreedat_go/core/utils/api_client.dart';
import 'package:tawreedat_go/core/utils/logger.dart';

import '../models/slot_model.dart';

class SlotRepository {
  /// Uses the shared [ApiClient] singleton which already handles:
  ///   • Bearer token injection
  ///   • 401 → session clear + redirect to login
  ///   • Timeout / connectivity friendly Arabic error messages
  ///   • 30-day session-age enforcement
  final _dio = ApiClient.instance.dio;

  /// Fetches upcoming slot availability for [storeAddressId].
  ///
  /// [days] controls how many calendar days ahead to include (default: 7).
  /// Throws a [DioException] with a user-friendly message on failure — the
  /// interceptor has already replaced raw server errors/HTML with readable
  /// Arabic strings, so callers can surface [e.message] directly in the UI.
  Future<SlotStatusData> fetchSlots() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://tawreedatsupplierapis.nitg-eg.com/api/v1/supplier/profile/supplier-slot-max-order-status/1',
      );

      return SlotStatusData.fromJson(response.data!);
    } on DioException catch (e, stackTrace) {
      dLog('[SlotRepository] DioException: ${e.message}');
      dLog('[SlotRepository] Status code: ${e.response?.statusCode}');
      dLog('[SlotRepository] Response data: ${e.response?.data}');
      dLog('[SlotRepository] Stack trace: $stackTrace');
      rethrow;
    } catch (e, stackTrace) {
      dLog('[SlotRepository] Unexpected error: $e');
      dLog('[SlotRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }
}