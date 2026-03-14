import 'dart:developer';
import 'package:dio/dio.dart';

import '../../core/utils/api_client.dart';

class AppInfoModel {
  final String id;
  final String terms;
  final String termsAr;
  final String about;
  final String aboutAr;
  final String privacyPolicy;
  final String privacyPolicyAr;
  final String mission;
  final String missionAr;
  final String vision;
  final String visionAr;
  final String digitalCard;
  final String digitalCardAr;
  final String supportNumber;
  final String instaPayNumber;
  final String vodafonCashNumber;
  final String email;
  final String facebook;
  final String instagram;
  final String linkedin;
  final String pinterest;
  final String reddit;
  final String snapchat;
  final String telegram;
  final String tiktok;
  final String twitter;
  final String whatsapp;
  final String youtube;

  AppInfoModel({
    required this.id,
    required this.terms,
    required this.termsAr,
    required this.about,
    required this.aboutAr,
    required this.privacyPolicy,
    required this.privacyPolicyAr,
    required this.mission,
    required this.missionAr,
    required this.vision,
    required this.visionAr,
    required this.digitalCard,
    required this.digitalCardAr,
    required this.email,
    required this.facebook,
    required this.instagram,
    required this.linkedin,
    required this.pinterest,
    required this.reddit,
    required this.snapchat,
    required this.telegram,
    required this.tiktok,
    required this.twitter,
    required this.whatsapp,
    required this.youtube,
    required this.supportNumber,
    required this.instaPayNumber,
    required this.vodafonCashNumber,
  });

  factory AppInfoModel.fromJson(Map<String, dynamic> json) {
    return AppInfoModel(
      id: json['id'].toString(),
      terms: json['terms'] ?? '',
      termsAr: json['terms_ar'] ?? '',
      about: json['about'] ?? '',
      aboutAr: json['about_ar'] ?? '',
      privacyPolicy: json['privacy_policy'] ?? '',
      privacyPolicyAr: json['privacy_policy_ar'] ?? '',
      mission: json['mission'] ?? '',
      missionAr: json['mission_ar'] ?? '',
      vision: json['vision'] ?? '',
      visionAr: json['vision_ar'] ?? '',
      digitalCard: json['digital_card'] ?? '',
      digitalCardAr: json['digital_card_ar'] ?? '',
      supportNumber: json['customer_support_number'] ?? '',
      instaPayNumber: json['instapay_number'] ?? '',
      vodafonCashNumber: json['vodafon_cash_number'] ?? '',
      email: json['email'] ?? '',
      facebook: json['facebook'] ?? '',
      instagram: json['instagram'] ?? '',
      linkedin: json['linkedin'] ?? '',
      pinterest: json['pinterest'] ?? '',
      reddit: json['reddit'] ?? '',
      snapchat: json['snapchat'] ?? '',
      telegram: json['telegram'] ?? '',
      tiktok: json['tiktok'] ?? '',
      twitter: json['twitter'] ?? '',
      whatsapp: json['whatsapp'] ?? '',
      youtube: json['youtube'] ?? '',
    );
  }
}

class AppInfoManager {
  static final AppInfoManager _instance = AppInfoManager._internal();

  factory AppInfoManager() => _instance;

  AppInfoManager._internal();

  AppInfoModel? _appInfo;
  final Dio _dio = ApiClient.instance.dio;

  AppInfoModel? get data => _appInfo;

  bool get isLoaded => _appInfo != null;

  Future<void> loadAppInfo() async {
    try {
      final response = await _dio.get('/about-app');
      if (response.statusCode == 200 && response.data['about_app'] != null) {
        _appInfo = AppInfoModel.fromJson(response.data['about_app']);
        log('✅ App info loaded successfully');
      } else {
        log('⚠️ Failed to load app info: ${response.statusCode}');
      }
    } catch (e, s) {
      log('❌ Error loading app info: $e', stackTrace: s);
    }
  }
}
