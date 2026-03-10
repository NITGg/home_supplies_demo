import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
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

      log('Get profile response: ${response.data}');
      return ProfileResponseModel.fromJson(response.data);
    } catch (e) {
      log('Get profile error: $e');
      rethrow;
    }
  }

  /// UPDATE PROFILE (basic info)
  Future<UpdateProfileResponseModel> updateProfile({
    required String token,
    String? fullName,
    String? gender,
    String? lang,
  }) async {
    try {
      final Map<String, dynamic> data = {};

      if (fullName != null) data['full_name'] = fullName;
      if (gender != null) data['gender'] = gender;
      if (lang != null) data['lang'] = lang;

      final response = await _dio.put(
        '/profile?lang=${LocaleManager.currentLocale}',
        data: data,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      log('Update profile response: ${response.data}');
      return UpdateProfileResponseModel.fromJson(response.data);
    } catch (e) {
      log('Update profile error: $e');
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
  }) async {
    try {
      final formData = FormData();

      if (fullName != null) {
        formData.fields.add(MapEntry('full_name', fullName));
      }
      if (gender != null) {
        formData.fields.add(MapEntry('gender', gender));
      }
      if (lang != null) {
        formData.fields.add(MapEntry('lang', lang));
      }
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
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      log('Update profile with photo response: ${response.data}');
      return UpdateProfileResponseModel.fromJson(response.data);
    } catch (e) {
      log('Update profile with photo error: $e');
      rethrow;
    }
  }
}