import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tawreedat/core/utils/api_client.dart';

class AppSettings {
  static final AppSettings _instance = AppSettings._internal();

  factory AppSettings() {
    return _instance;
  }

  AppSettings._internal();

  static String? android_version ;
  static String? ios_url ;
  static String? ios_version ;
  static String? android_url ;

  static int? numberOfProductsOnHomepage;
  static int? numberOfAdsOnHomepage;
  static int? numberOfBrandsOnHomepage;
  static int? numberOfCategoriesOnHomepage;
  static int? numberOfFeaturedProductsOnHomepage;
  static int? numberOfLatestOffersOnHomepage;
  static int? numberOfNewArrivalsOnHomepage;
  static int? login_attempts;
  static int? login_attempt_duration_minutes;
  static String? last_attempt;
  static int? payment_attempts;

  static int? vat;
  static bool? loginAsGuest;
  static bool? permanentDelete;

  /// Fetch settings from API
  Future<void> load() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiClient.baseUrl}/api/app-settings/mobile"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final settings = data['settings'];
        android_version = settings['app_android_version'];
        ios_url = settings['app_ios_url'];
        ios_version = settings['app_ios_version'];
        android_url = settings['app_android_url'];
        numberOfProductsOnHomepage = settings['number_of_products_on_homepage'];
        numberOfBrandsOnHomepage = settings['number_of_brands_on_homepage'];
        numberOfAdsOnHomepage = settings['number_of_ads_on_homepage'];
        numberOfCategoriesOnHomepage = settings['number_of_categories_on_homepage'];
        numberOfFeaturedProductsOnHomepage =
            settings['number_of_featured_products_on_homepage'];
        numberOfLatestOffersOnHomepage =
            settings['number_of_latest_offers_on_homepage'];
        numberOfNewArrivalsOnHomepage =
            settings['number_of_new_arrivals_on_homepage'];

        vat = settings['vat'];
        loginAsGuest = settings['login_as_guest'];
        last_attempt = settings['last_attempt'];
        login_attempt_duration_minutes = settings['login_attempt_duration_minutes'];
        login_attempts = settings['login_attempts'];
        payment_attempts = settings['payment_attempts'];
      } else {
        throw Exception("Failed to fetch settings: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error loading settings: $e");
    }
  }
}
