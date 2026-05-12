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
  /// CHANGE MAIN PHONE (triggers OTP)
  Future<Map<String, dynamic>> changePhone({
    required String token,
    required String phone,
  }) async {
    try {
      final response = await _dio.post(
        '/profile/change-phone?lang=${LocaleManager.currentLocale}',
        data: {'phone': phone},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      dLog('Change phone response: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      dLog('Change phone error: $e');
      rethrow;
    }
  }

  /// CHANGE EMAIL (triggers OTP)
  Future<Map<String, dynamic>> changeEmail({
    required String token,
    required String email,
  }) async {
    try {
      final response = await _dio.post(
        '/profile/change-email?lang=${LocaleManager.currentLocale}',
        data: {'email': email},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      dLog('Change email response: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      dLog('Change email error: $e');
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

  /// CONFIRM OTP (after change-phone or change-email)
  Future<Map<String, dynamic>> confirmOtp({
    required String token,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '/profile/confirm-otp?lang=${LocaleManager.currentLocale}',
        data: {'code': code},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      dLog('Confirm OTP response: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      dLog('Confirm OTP error: $e');
      rethrow;
    }
  }
}