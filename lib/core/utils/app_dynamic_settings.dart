import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tawreedat_courier/core/utils/logger.dart';

import 'api_client.dart';

class AppSettings {
  static final AppSettings _instance = AppSettings._internal();

  factory AppSettings() {
    return _instance;
  }

  AppSettings._internal();

  static String? android_version;
  static bool? paymob_enabled;
  static bool? kashier_enabled;
  static bool? easykash_enabled;

  static String? ios_url;
  static bool? chat_enable_send_images;

  static String? ios_version;

  static String? android_url;

  static String? min_delivery_distance;

  static int? courier_max_selected_areas;
  static int? max_orders_per_trip;

  static bool? skipOtp;

  static int? otp_length;
  static int? otp_resend_duration_seconds;

  /// Failures are swallowed so this can't block app startup while unused.
  Future<void> loadPublicSettings() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiClient.baseUrl}/app-settings/public"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        dLog(data.toString());
        // Handle both possible nesting levels from the API
        final Map<String, dynamic> settings =
            (data['data']['ApplicationSettings'] as Map<String, dynamic>?) ??
            (data['data'] as Map<String, dynamic>? ?? {});
        otp_length = _toInt(settings['otp_length']);
        otp_resend_duration_seconds =
            _toInt(settings['otp_resend_duration_seconds']);
        dLog('AppSettings: otp_length=$otp_length, otp_resend_duration_seconds=$otp_resend_duration_seconds');
      }
    } catch (e) {
      dLog("Error loading public settings: $e");
    }
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Fetch settings from API
  Future<void> load() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiClient.baseUrl}/order/app-settings"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        dLog(data.toString());
        final settings = data['data']['ApplicationSettings'];
        android_version = settings['courier_app_version_android'];
        chat_enable_send_images = settings['chat_enable_send_images'] as bool?;
        ios_url = settings['courier_app_url_ios'];
        ios_version = settings['courier_app_version_ios'];
        kashier_enabled = settings['kashier_enabled'] as bool?;
        paymob_enabled = settings['paymob_enabled'] as bool?;
        easykash_enabled = settings['easykash_enabled'] as bool?;
        android_url = settings['courier_app_url_android'];
        min_delivery_distance = settings['min_delivery_distance'];
        skipOtp = settings['skip_otp'] == true || settings['skip_otp'] == 'true';
        courier_max_selected_areas = settings['courier_max_selected_areas'];
        max_orders_per_trip = settings['max_orders_per_trip'];
        otp_length = _toInt(settings['otp_length']);
        otp_resend_duration_seconds =
            _toInt(settings['otp_resend_duration_seconds']);
        dLog('AppSettings load(): otp_length=$otp_length, otp_resend_duration_seconds=$otp_resend_duration_seconds');
      } else {
        throw Exception("Failed to fetch settings: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error loading settings: $e");
    }
  }
}
