import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tawreedat_go/core/utils/logger.dart';
import 'api_client.dart';

class AppSettings {
  static final AppSettings _instance = AppSettings._internal();

  factory AppSettings() {
    return _instance;
  }

  AppSettings._internal();

  static String? android_version;
  static int platform_supplier_id = 9;
  static int home_categories_grid_limit = 6;
  static String? ios_url;
  static bool? chat_enable_send_images;
  static bool? paymob_enabled;
  static bool? kashier_enabled;

  static String? ios_version;

  static String? android_url;

  static String? min_delivery_distance;

  static String? min_delivery_fee;

  static String? delivery_price_for_each_1km;

  static String? delivery_fee_ratio;
  static String? customer_budget_cash_on_delivery_limit;
  static String? customer_catalog_cod_limit;

  /// Fetch settings from API
  Future<void> load() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiClient.baseUrl}/app-settings/public"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        dLog(data.toString());
        final settings = data['settings'];
        android_version = settings['app_android_version'];
        ios_url = settings['app_ios_url'];
        platform_supplier_id = (settings['platform_supplier_id'] as int?) ?? 9;
        home_categories_grid_limit = (settings['home_categories_grid_limit'] as int?) ?? 6;
        chat_enable_send_images = settings['chat_enable_send_images'] as bool?;
        kashier_enabled = settings['kashier_enabled'] as bool?;
        paymob_enabled = settings['paymob_enabled'] as bool?;
        customer_budget_cash_on_delivery_limit =
            settings['customer_budget_cash_on_delivery_limit'];
        customer_catalog_cod_limit = settings['customer_catalog_cod_limit'];
        ios_version = settings['app_ios_version'];
        android_url = settings['app_android_url'];
        min_delivery_distance = settings['min_delivery_distance'];
        min_delivery_fee = settings['min_delivery_fee'];
        delivery_price_for_each_1km = settings['delivery_price_for_each_1km'];
        delivery_fee_ratio = settings['delivery_fee_ratio'];
      } else {
        throw Exception("Failed to fetch settings: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error loading settings: $e");
    }
  }
}
