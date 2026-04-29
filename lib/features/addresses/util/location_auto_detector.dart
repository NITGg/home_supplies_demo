import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/constants.dart';
import '../../../core/utils/location_service.dart';

class LocationAutoDetector {
  LocationAutoDetector._();

  /// Detects the device's current location and reverse-geocodes it.
  ///
  /// Returns the same [Map<String, String>] shape that
  /// [MapLocationPickerScreen] returns via [Navigator.pop], so it can be
  /// injected directly into [AddressFormBottomSheet] without any adaptation.
  ///
  /// Returns `null` if:
  ///   • permission is denied / service disabled (LocationService handles dialogs)
  ///   • reverse-geocoding fails
  ///   • the response contains no results
  static Future<Map<String, String>?> detect({
    required BuildContext context,
    required String language,
  }) async {
    try {
      log('Auto address called ...');

      // ── 1. Get GPS position via the existing service ──────────────────────
      // All permission dialogs, retry loops, and settings-open flows are
      // handled inside LocationService — nothing to duplicate here.
      final position = await LocationService.instance.getCurrentLocation(
        context: context,
      );

      if (position == null) {
        log('LocationAutoDetector: position is null — permission denied or service off');
        return null;
      }

      log('LocationAutoDetector: got position ${position.latitude}, ${position.longitude}');

      // ── 2. Reverse-geocode (same endpoint used by map_location_picker) ────
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
            '?latlng=${position.latitude},${position.longitude}'
            '&language=$language'
            '&key=${AppConstants.googleMapsApiKey}',
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        log('LocationAutoDetector: geocoding HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['status'] != 'OK') {
        log('LocationAutoDetector: geocoding status ${data['status']}');
        return null;
      }

      final results = data['results'] as List<dynamic>;
      if (results.isEmpty) {
        log('LocationAutoDetector: no geocoding results');
        return null;
      }

      // ── 3. Parse address components ───────────────────────────────────────
      // Mirrors location_picker_screen.dart → onNext exactly:
      //   administrative_area_level_2 → district / area
      //   administrative_area_level_1 → governorate
      String? administrativeArea;
      String? governorate;

      final components =
          results.first['address_components'] as List<dynamic>? ?? [];

      for (final component in components) {
        final types = (component['types'] as List<dynamic>).cast<String>();
        if (types.contains('administrative_area_level_2')) {
          administrativeArea ??= component['long_name'] as String;
        }
        if (types.contains('administrative_area_level_1')) {
          governorate ??= component['long_name'] as String;
        }
      }

      final formattedAddress =
          results.first['formatted_address'] as String? ?? '';

      log('LocationAutoDetector: area="$administrativeArea" gov="$governorate" address="$formattedAddress"');

      return {
        'latitude': '${position.latitude}',
        'longitude': '${position.longitude}',
        'address': formattedAddress,
        'administrativeArea': administrativeArea ?? '',
        'governorate': governorate ?? '',
      };
    } catch (e) {
      log('LocationAutoDetector: error — $e');
      return null;
    }
  }
}