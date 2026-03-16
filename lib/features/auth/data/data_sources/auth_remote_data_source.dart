import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/auth_response_model.dart';
import '../models/user_profile_model.dart';

class AuthRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<ShortAuthResponseModel> register({
    required BuildContext context,
    required String fullName,
    required String phone,
    required String password,
    String? email,
  }) async {
    final Map<String, dynamic> data = {
      'full_name': fullName,
      'phone': phone,
      'password': password,
    };

    if (email != null && email.isNotEmpty) {
      data['email'] = email;
    }

    final response = await _dio.post(
      '/auth/register?lang=${LocaleManager.currentLocale}',
      data: data,
      options: Options(
        headers: {'Accept-Language': LocaleManager.currentLocale},
      ),
    );

    return ShortAuthResponseModel.fromJson(response.data);
  }

  Future<ShortAuthResponseModel> login({
    required String phone,
    required String password,
    String locale = 'en',
  }) async {
    final response = await _dio.post(
      '/auth/login?lang=${LocaleManager.currentLocale}',
      data: {
        'phone': phone,
        'password': password,
      },
      options: Options(
        headers: {'Accept-Language': LocaleManager.currentLocale},
      ),
    );

    return ShortAuthResponseModel.fromJson(response.data);
  }

  Future<ProfileResponseModel> getProfile(String token) async {
    final response = await _dio.get(
      '/profile?lang=${LocaleManager.currentLocale}',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    return ProfileResponseModel.fromJson(response.data);
  }

  Future<DeleteProfileResponseModel> deleteProfile(String token) async {
    final response = await _dio.delete(
      '/profile?lang=${LocaleManager.currentLocale}',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    return DeleteProfileResponseModel.fromJson(response.data);
  }

  Future<LongAuthResponseModel> verifyGoogleToken(String idToken) async {
    final response = await _dio.post(
      '/auth/google/verify?lang=${LocaleManager.currentLocale}',
      data: {'idToken': idToken},
    );

    final authResponse = LongAuthResponseModel.fromJson(response.data);
    log('Google sign in user: ${authResponse.token}');
    return authResponse;
  }

  Future<LongAuthResponseModel> verifyAppleToken(
      String idToken,
      String? fullName,
      ) async {
    final response = await _dio.post(
      '/auth/apple/verify?lang=${LocaleManager.currentLocale}',
      data: {
        'idToken': idToken,
        'fullname': fullName,
      },
    );

    final authResponse = LongAuthResponseModel.fromJson(response.data);
    log('Apple sign in user: ${authResponse.token}');
    return authResponse;
  }

  Future<UpdateProfileResponseModel> updateProfile({
    required String token,
    String? fullName,
    String? gender,
    String? lang,
    File? personalPhoto,
  }) async {
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

    try {
      log('Update profile response: ${response.data}');
      final updateResponse = UpdateProfileResponseModel.fromJson(response.data);
      log('Updated user profile: ${updateResponse.user.fullName}');
      return updateResponse;
    } catch (e, s) {
      log('Error parsing updated user profile', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<void> changePassword({
    required BuildContext context,
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await _dio.post(
      '/profile/change-password?lang=${LocaleManager.currentLocale}',
      data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      },
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(response.data['message'] ?? 'Failed to change password');
    }
  }
}