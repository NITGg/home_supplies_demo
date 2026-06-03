import 'dart:io';

import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/user_profile_model.dart';

class ProfileRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  /// GET PROFILE
  Future<ProfileResponseModel> getProfile(String token) async {
    try {
      final response = await _dio.get(
        '/profile?lang=${LocaleManager.currentLocale}',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      dLog('Get profile response: ${response.data}');
      return ProfileResponseModel.fromJson(response.data);
    } catch (e) {
      dLog('Get profile error: $e');
      rethrow;
    }
  }
  /// UPDATE PROFILE (basic info)
  Future<UpdateProfileResponseModel> updateProfile({
    required String token,
    String? fullName,
    String? gender,
    String? lang,
    String? phone,
    String? extraPhones,
  }) async {
    try {
      final Map<String, dynamic> data = {};

      if (fullName != null) data['full_name'] = fullName;
      if (gender != null) data['gender'] = gender;
      if (lang != null) data['lang'] = lang;
      if (phone != null) data['phone'] = phone;
      if (extraPhones != null) data['extra_phones'] = extraPhones;

      final response = await _dio.put(
        '/profile?lang=${LocaleManager.currentLocale}',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      dLog('Update profile response: ${response.data}');
      return UpdateProfileResponseModel.fromJson(response.data);
    } catch (e) {
      dLog('Update profile error: $e');
      rethrow;
    }
  }
  /// Sends OTP to both old and new contact values.
  /// [type] is "phone" or "email", [newValue] is the new contact value.
  Future<Map<String, dynamic>> changeContactInfo({
    required String token,
    required String type,
    required String newValue,
  }) async {
    try {
      dLog('📤 POST /auth/change-phone-email — type=$type newValue=$newValue');
      final response = await _dio.post(
        '/auth/change-phone-email?lang=${LocaleManager.currentLocale}',
        data: {'type': type, 'new_value': newValue},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      dLog('📥 /auth/change-phone-email — status: ${response.statusCode} body: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      dLog('changeContactInfo error: $e');
      rethrow;
    }
  }

  /// UPDATE PROFILE WITH PHOTO
  Future<UpdateProfileResponseModel> updateProfileWithPhoto({
    required String token,
    String? fullName,
    String? gender,
    String? lang,
    File? personalPhoto,
    String? extraPhones,
  }) async {
    try {
      final formData = FormData();

      if (fullName != null) formData.fields.add(MapEntry('full_name', fullName));
      if (gender != null) formData.fields.add(MapEntry('gender', gender));
      if (lang != null) formData.fields.add(MapEntry('lang', lang));
      if (extraPhones != null) formData.fields.add(MapEntry('extra_phones', extraPhones));
      if (personalPhoto != null) {
        formData.files.add(MapEntry(
          'personal_photo',
          await MultipartFile.fromFile(
            personalPhoto.path,
            filename: 'personal_photo.jpg',
          ),
        ));
      }

      final response = await _dio.put(
        '/profile?lang=${LocaleManager.currentLocale}',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      dLog('Update profile with photo response: ${response.data}');
      return UpdateProfileResponseModel.fromJson(response.data);
    } catch (e) {
      dLog('Update profile with photo error: $e');
      rethrow;
    }
  }

  /// POST /profile/change-phone — requests an OTP to verify the new phone.
  /// Returns the raw response map (contains `message` and optionally `via`).
  Future<Map<String, dynamic>> changePhone({
    required String token,
    required String phone,
  }) async {
    try {
      dLog('📤 POST /profile/change-phone — phone=$phone');
      final response = await _dio.post(
        '/profile/change-phone?lang=${LocaleManager.currentLocale}',
        data: {'phone': phone},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      dLog('📥 /profile/change-phone — status: ${response.statusCode} body: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      dLog('changePhone error: $e');
      rethrow;
    }
  }

  /// Verifies OTPs sent to both old and new contact values.
  Future<Map<String, dynamic>> verifyContactChange({
    required String token,
    required String oldCode,
    required String newCode,
  }) async {
    try {
      dLog('📤 POST /auth/verify-old-new-phone-email — oldCode=$oldCode newCode=$newCode');
      final response = await _dio.post(
        '/auth/verify-old-new-phone-email?lang=${LocaleManager.currentLocale}',
        data: {'old_code': oldCode, 'new_code': newCode},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      dLog('📥 /auth/verify-old-new-phone-email — status: ${response.statusCode} body: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      dLog('verifyContactChange error: $e');
      rethrow;
    }
  }
}