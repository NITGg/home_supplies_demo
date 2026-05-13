import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/auth_response_model.dart';
import '../models/user_profile_model.dart';
class ImageValidationException implements Exception {
  final String message;
  const ImageValidationException(this.message);
  @override
  String toString() => 'ImageValidationException: $message';
}
class AuthRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;
  static const _allowedMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};

  Future<void> _validateImage(File file) async {
    final bytes = await file.readAsBytes();
    final mimeType = lookupMimeType(file.path, headerBytes: bytes);
    if (!_allowedMimeTypes.contains(mimeType)) {
      throw const ImageValidationException(
        'Only JPEG, PNG, or WEBP images are allowed',
      );
    }
  }
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
    dLog('Google sign in user: ${authResponse.token}');
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
    dLog('Apple sign in user: ${authResponse.token}');
    return authResponse;
  }

  Future<UpdateProfileResponseModel> updateProfile({
    required String token,
    String? fullName,
    String? gender,
    String? lang,
    File? personalPhoto,
  }) async {
    if (personalPhoto != null) await _validateImage(personalPhoto);

    final formData = FormData();

    if (fullName != null) formData.fields.add(MapEntry('full_name', fullName));
    if (gender != null) formData.fields.add(MapEntry('gender', gender));
    if (lang != null) formData.fields.add(MapEntry('lang', lang));
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
      dLog('Update profile response: ${response.data}');
      final updateResponse = UpdateProfileResponseModel.fromJson(response.data);
      dLog('Updated user profile: ${updateResponse.user.fullName}');
      return updateResponse;
    } catch (e, s) {
      dLog('Error parsing updated user profile $e $s');
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

  Future<void> forgotPassword({String? phone, String? email}) async {
    final Map<String, dynamic> data = {};
    if (phone != null) data['phone'] = phone;
    if (email != null) data['email'] = email;

    await _dio.post(
      '/auth/forget-password?lang=${LocaleManager.currentLocale}',
      data: data,
      options: Options(
        headers: {'Accept-Language': LocaleManager.currentLocale},
      ),
    );
  }

  Future<void> resetPassword({
    required String code,
    required String password,
  }) async {
    await _dio.post(
      '/auth/reset-password?lang=${LocaleManager.currentLocale}',
      data: {'code': code, 'password': password},
      options: Options(
        headers: {'Accept-Language': LocaleManager.currentLocale},
      ),
    );
  }

  Future<void> resendOtp({required String phone}) async {
    await _dio.post(
      '/auth/resend-otp?lang=${LocaleManager.currentLocale}',
      data: {'phone': phone},
      options: Options(
        headers: {'Accept-Language': LocaleManager.currentLocale},
      ),
    );
  }

  Future<void> logout() async {
    await _dio.post(
      '/auth/logout?lang=${LocaleManager.currentLocale}',
      options: Options(
        headers: {'Accept-Language': LocaleManager.currentLocale},
      ),
    );
  }
}