import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/secure_storage_service.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/auth_response_model.dart';
import '../models/user_profile_model.dart';
import '../models/vehicles_model.dart';

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

  /// Validates all non-null files in one call.
  Future<void> _validateImages(List<File?> files) async {
    for (final file in files) {
      if (file != null) await _validateImage(file);
    }
  }

  /// GET AVAILABLE VEHICLES (public endpoint — no auth required)
  Future<AvailableVehiclesResponseModel> fetchAvailableVehicles() async {
    try {
      final response = await _dio.get('/auth/available-vehicles');
      dLog('Available vehicles: ${response.data}');
      return AvailableVehiclesResponseModel.fromJson(response.data);
    } catch (e) {
      dLog('fetchAvailableVehicles error: $e');
      rethrow;
    }
  }

  /// REGISTER
  Future<AuthResponseModel> register({
    required BuildContext context,
    required String fullName,
    required String phone,
    required String password,
    required String gender,
    required String vehicleId,
    required String vehiclePlate,
    required String nationalId,
    required File? personalPhoto,
    required File nationalIdPhotoFront,
    required File nationalIdPhotoBack,
    File? vehicleLicenseFront,
    File? vehicleLicenseBack,
    File? courierLicenseFront,
    File? courierLicenseBack,
    File? criminalRecord,
  }) async {
    try {
      await _validateImages([
        personalPhoto,
        nationalIdPhotoFront,
        nationalIdPhotoBack,
        vehicleLicenseFront,
        vehicleLicenseBack,
        courierLicenseFront,
        courierLicenseBack,
        criminalRecord,
      ]);
      final formData = FormData.fromMap({
        'full_name': fullName,
        'phone': phone,
        'password': password,
        'gender': gender,
        'vehicle_id': vehicleId,
        'vehicle_plate': vehiclePlate,
        'national_id_number': nationalId,
        if (personalPhoto != null)
          'personal_photo': await MultipartFile.fromFile(
            personalPhoto.path,
            filename: 'personal_photo.jpg',
          ),
        'national_id_photo_front': await MultipartFile.fromFile(
          nationalIdPhotoFront.path,
          filename: 'national_id_front.jpg',
        ),
        'national_id_photo_back': await MultipartFile.fromFile(
          nationalIdPhotoBack.path,
          filename: 'national_id_back.jpg',
        ),
        if (vehicleLicenseFront != null)
          'vehicle_license_front': await MultipartFile.fromFile(
            vehicleLicenseFront.path,
            filename: 'vehicle_license_front.jpg',
          ),
        if (vehicleLicenseBack != null)
          'vehicle_license_back': await MultipartFile.fromFile(
            vehicleLicenseBack.path,
            filename: 'vehicle_license_back.jpg',
          ),
        if (courierLicenseFront != null)
          'courier_license_front': await MultipartFile.fromFile(
            courierLicenseFront.path,
            filename: 'courier_license_front.jpg',
          ),
        if (courierLicenseBack != null)
          'courier_license_back': await MultipartFile.fromFile(
            courierLicenseBack.path,
            filename: 'courier_license_back.jpg',
          ),
        if (criminalRecord != null)
          'courier_criminal_record': await MultipartFile.fromFile(
            criminalRecord.path,
            filename: 'criminal_record.jpg',
          ),
      });

      final response = await _dio.post(
        '/auth/register?lang=${LocaleManager.currentLocale}',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return AuthResponseModel.fromJson(response.data);
    } catch (e) {
      dLog('Register error: $e');
      rethrow;
    }
  }


  /// dLogIN
  Future<AuthResponseModel> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login?lang=${LocaleManager.currentLocale}',
        data: {'phone': phone, 'password': password},
      );

      return AuthResponseModel.fromJson(response.data);
    } catch (e) {
      dLog('dLogin error: $e');
      rethrow;
    }
  }

  /// REFRESH TOKEN
  Future<RefreshTokenResponse> refreshToken({
    required String refreshToken,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/refresh-token?lang=${LocaleManager.currentLocale}',
        options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
      );

      return RefreshTokenResponse.fromJson(response.data);
    } catch (e) {
      dLog('Refresh token error: $e');
      rethrow;
    }
  }

  /// DELETE PROFILE
  Future<Map<String, dynamic>> deleteProfile() async {
    try {
      final response = await _dio.delete('/profile/soft-delete?lang=ar');
      return response.data;
    } catch (e) {
      dLog('Delete profile error: $e');
      rethrow;
    }
  }

  Future<void> changePassword({
    required BuildContext context,
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await _dio.patch(
      '/auth/update-password?lang=ar',
      data: {'current_password': oldPassword, 'new_password': newPassword},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode != 200) {
      throw Exception(response.data['message'] ?? 'Failed to change password');
    }
  }

  /// UPDATE PROFILE
  Future<UserProfileModel> updateProfile({
    required Map<String, dynamic> data,
    File? imageUrl,
  }) async {
    try {
      await _validateImages([imageUrl]);

      if (imageUrl != null) {
        data.remove('imageUrl');
        data['imageUrl'] = await MultipartFile.fromFile(imageUrl.path);
      }
      final formData = FormData.fromMap(data);

      final response = await _dio.put(
        '/profile?lang=${LocaleManager.currentLocale}',
        data: formData,
      );

      dLog(response.data.toString());
      final updatedUser = UserProfileModel.fromJson(
        response.data['updatedUser'],
      );
      dLog('Updated user profile: ${updatedUser.toString()}');
      return updatedUser;
    } catch (e) {
      dLog('Error parsing updated user profile');
      rethrow;
    }
  }

  /// GOOGLE REGISTER
  Future<AuthResponseModel> googleRegister({
    required String idToken,
    required String fullName,
    required String phone,
    required String gender,
    required String vehicleId,
    required String nationalId,
    required String vehiclePlate,
    required File? personalPhoto,
    required File nationalIdPhotoFront,
    required File nationalIdPhotoBack,
    File? vehicleLicenseFront,
    File? vehicleLicenseBack,
    File? courierLicenseFront,
    File? courierLicenseBack,
    File? criminalRecord,
  }) async {
    try {
      await _validateImages([
        personalPhoto,
        nationalIdPhotoFront,
        nationalIdPhotoBack,
        vehicleLicenseFront,
        vehicleLicenseBack,
        courierLicenseFront,
        courierLicenseBack,
        criminalRecord,
      ]);
      final formData = FormData.fromMap({
        'id_token': idToken,
        'full_name': fullName,
        'phone': phone,
        'gender': gender,
        'vehicle_id': vehicleId,
        'national_id_number': nationalId,
        'vehicle_plate': vehiclePlate,
        if (personalPhoto != null)
          'personal_photo': await MultipartFile.fromFile(
            personalPhoto.path,
            filename: 'personal_photo.jpg',
          ),
        'national_id_photo_front': await MultipartFile.fromFile(
          nationalIdPhotoFront.path,
          filename: 'national_id_front.jpg',
        ),
        'national_id_photo_back': await MultipartFile.fromFile(
          nationalIdPhotoBack.path,
          filename: 'national_id_back.jpg',
        ),
        if (vehicleLicenseFront != null)
          'vehicle_license_front': await MultipartFile.fromFile(
            vehicleLicenseFront.path,
            filename: 'vehicle_license_front.jpg',
          ),
        if (vehicleLicenseBack != null)
          'vehicle_license_back': await MultipartFile.fromFile(
            vehicleLicenseBack.path,
            filename: 'vehicle_license_back.jpg',
          ),
        if (courierLicenseFront != null)
          'courier_license_front': await MultipartFile.fromFile(
            courierLicenseFront.path,
            filename: 'courier_license_front.jpg',
          ),
        if (courierLicenseBack != null)
          'courier_license_back': await MultipartFile.fromFile(
            courierLicenseBack.path,
            filename: 'courier_license_back.jpg',
          ),
        if (criminalRecord != null)
          'courier_criminal_record': await MultipartFile.fromFile(
            criminalRecord.path,
            filename: 'criminal_record.jpg',
          ),
      });

      final response = await _dio.post(
        '/auth/google-register?lang=${LocaleManager.currentLocale}',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return AuthResponseModel.fromJson(response.data);
    } catch (e) {
      dLog('googleRegister error: $e');
      rethrow;
    }
  }

  /// APPLE REGISTER
  Future<AuthResponseModel> appleRegister({
    required String idToken,
    required String fullName,
    required String phone,
    required String gender,
    required String vehicleId,
    required String nationalId,
    required String vehiclePlate,
    required File? personalPhoto,
    required File nationalIdPhotoFront,
    required File nationalIdPhotoBack,
    File? vehicleLicenseFront,
    File? vehicleLicenseBack,
    File? courierLicenseFront,
    File? courierLicenseBack,
    File? criminalRecord,
  }) async {
    try {
      await _validateImages([
        personalPhoto,
        nationalIdPhotoFront,
        nationalIdPhotoBack,
        vehicleLicenseFront,
        vehicleLicenseBack,
        courierLicenseFront,
        courierLicenseBack,
        criminalRecord,
      ]);
      final formData = FormData.fromMap({
        'id_token': idToken,
        'full_name': fullName,
        'phone': phone,
        'gender': gender,
        'vehicle_id': vehicleId,
        'national_id_number': nationalId,
        'vehicle_plate': vehiclePlate,
        if (personalPhoto != null)
          'personal_photo': await MultipartFile.fromFile(
            personalPhoto.path,
            filename: 'personal_photo.jpg',
          ),
        'national_id_photo_front': await MultipartFile.fromFile(
          nationalIdPhotoFront.path,
          filename: 'national_id_front.jpg',
        ),
        'national_id_photo_back': await MultipartFile.fromFile(
          nationalIdPhotoBack.path,
          filename: 'national_id_back.jpg',
        ),
        if (vehicleLicenseFront != null)
          'vehicle_license_front': await MultipartFile.fromFile(
            vehicleLicenseFront.path,
            filename: 'vehicle_license_front.jpg',
          ),
        if (vehicleLicenseBack != null)
          'vehicle_license_back': await MultipartFile.fromFile(
            vehicleLicenseBack.path,
            filename: 'vehicle_license_back.jpg',
          ),
        if (courierLicenseFront != null)
          'courier_license_front': await MultipartFile.fromFile(
            courierLicenseFront.path,
            filename: 'courier_license_front.jpg',
          ),
        if (courierLicenseBack != null)
          'courier_license_back': await MultipartFile.fromFile(
            courierLicenseBack.path,
            filename: 'courier_license_back.jpg',
          ),
        if (criminalRecord != null)
          'courier_criminal_record': await MultipartFile.fromFile(
            criminalRecord.path,
            filename: 'criminal_record.jpg',
          ),
      });

      final response = await _dio.post(
        '/auth/apple-register?lang=${LocaleManager.currentLocale}',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return AuthResponseModel.fromJson(response.data);
    } catch (e) {
      dLog('appleRegister error: $e');
      rethrow;
    }
  }

  /// GOOGLE SIGN IN
  Future<AuthResponseModel> verifyGoogleToken({required String idToken}) async {
    try {
      final response = await _dio.post(
        '/auth/google-login?lang=${LocaleManager.currentLocale}',
        data: {'id_token': idToken},
      );

      final authResponse = AuthResponseModel.fromJson(response.data);
        dLog('Google sign in user: ${authResponse.data.accessToken}');
      return authResponse;
    } catch (e) {
      dLog('Google sign in error: $e');
      rethrow;
    }
  }

  /// APPLE SIGN IN
  Future<AuthResponseModel> verifyAppleToken({
    required String idToken,
    String? fullName,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/apple-login?lang=${LocaleManager.currentLocale}',
        data: {'id_token': idToken},
      );

      final authResponse = AuthResponseModel.fromJson(response.data);
        dLog('Apple sign in user: ${authResponse.data.accessToken}');
      return authResponse;
    } catch (e) {
      dLog('Apple sign in error: $e');
      rethrow;
    }
  }

  /// FORGOT PASSWORD
  Future<ForgotPasswordResponse> forgotPassword({required String phone}) async {
    try {
      final response = await _dio.post(
        '/auth/forget-password?lang=${LocaleManager.currentLocale}',
        data: {'phone': phone},
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      dLog('Forgot password response: ${response.data}');
      return ForgotPasswordResponse.fromJson(response.data);
    } catch (e) {
      dLog('Forgot password error: $e');
      rethrow;
    }
  }

  /// RESET PASSWORD with OTP
  Future<ResetPasswordResponse> resetPassword({
    required String phone,
    required String userOtp,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.patch(
        '/auth/change-password?lang=${LocaleManager.currentLocale}',
        data: {
          'phone': phone,
          'user_otp': userOtp,
          'new_password': newPassword,
        },
      );

      return ResetPasswordResponse.fromJson(response.data);
    } catch (e) {
      dLog('Reset password error: $e');
      rethrow;
    }
  }

  /// LINK GOOGLE ACCOUNT
  Future<Map<String, dynamic>> linkGoogle({required String idToken}) async {
    try {
      final response = await _dio.post(
        '/auth/link-google?lang=${LocaleManager.currentLocale}',
        data: {'id_token': idToken},
      );
      dLog('Link Google response: ${response.data}');
      return response.data;
    } catch (e) {
      dLog('Link Google error: $e');
      rethrow;
    }
  }

  /// LINK APPLE ACCOUNT
  Future<Map<String, dynamic>> linkApple({
    required String idToken,
    String? fullName,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/link-apple?lang=${LocaleManager.currentLocale}',
        data: {'id_token': idToken},
      );
      dLog('Link Apple response: ${response.data}');
      return response.data;
    } catch (e) {
      dLog('Link Apple error: $e');
      rethrow;
    }
  }

  /// VERIFY OTP (unified endpoint for all verify_type values:
  /// VERIFY | RESET_PASSWORD | FORGET_PASSWORD | CHANGE_EMAIL | CHANGE_PHONE)
  /// For FORGET_PASSWORD: pass [newPassword] to reset the password in one call.
  /// For CHANGE_PHONE: pass [secondPhone] + [secondUserOtp] for the old number.
  Future<VerifyOtpResponse> verifyOtp({
    required String phone,
    required String userOtp,
    required String verifyType,
    String? newPassword,
    String? secondPhone,
    String? secondUserOtp,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/verify-otp?lang=${LocaleManager.currentLocale}',
        data: {
          'phone': phone,
          'user_otp': userOtp,
          'verify_type': verifyType,
          if (newPassword != null) 'new_password': newPassword,
          if (secondPhone != null) 'second_phone': secondPhone,
          if (secondUserOtp != null) 'second_user_otp': secondUserOtp,
        },
      );
      return VerifyOtpResponse.fromJson(response.data);
    } catch (e) {
      dLog('verifyOtp error: $e');
      rethrow;
    }
  }

  /// RESEND OTP (unified resend for all verify_type values)
  Future<VerifyOtpResponse> resendOtp({
    required String phone,
    required String verifyType,
    String? secondPhone,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/resend-otp?lang=${LocaleManager.currentLocale}',
        data: {
          'phone': phone,
          'verify_type': verifyType,
          if (secondPhone != null) 'second_phone': secondPhone,
        },
      );
      return VerifyOtpResponse.fromJson(response.data);
    } catch (e) {
      dLog('resendOtp error: $e');
      rethrow;
    }
  }

  Future<void> logOut() async {
    try {
      await _dio.post(
        '/auth/logout?lang=${LocaleManager.currentLocale}',
        options: Options(
          headers: {
            'Authorization':
                'Bearer ${await SecureStorageService().getToken()}',
          },
        ),
      );
    } catch (e) {
      dLog('Logout error: $e');
      rethrow;
    }
  }
}
