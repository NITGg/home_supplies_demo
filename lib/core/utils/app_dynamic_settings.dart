import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AppSettings {
  static final AppSettings _instance = AppSettings._internal();

  factory AppSettings() {
    return _instance;
  }

  AppSettings._internal();

  static String? android_version;
  static const int kMainSupplierId = 9;
  static String? ios_url;
  static bool? chat_enable_send_images;

  static String? ios_version;

  static String? android_url;

  static String? min_delivery_distance;

  static String? min_delivery_fee;

  static String? delivery_price_for_each_1km;

  static String? delivery_fee_ratio;
  static String? customer_budget_cash_on_delivery_limit;

  /// Fetch settings from API
  Future<void> load() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiClient.baseUrl}/app-settings/public"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final settings = data['settings'];
        android_version = settings['app_android_version'];
        ios_url = settings['app_ios_url'];
        chat_enable_send_images = settings['chat_enable_send_images'] as bool?;
        customer_budget_cash_on_delivery_limit = settings['customer_budget_cash_on_delivery_limit'];
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
