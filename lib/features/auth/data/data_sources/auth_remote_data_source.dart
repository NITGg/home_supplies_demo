import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/secure_storage_service.dart';
import '../models/auth_response_model.dart';
import '../models/user_profile_model.dart';

class AuthRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  /// REGISTER - New endpoint with courier data
  Future<AuthResponseModel> register({
    required BuildContext context,
    required String fullName,
    required String phone,
    required String password,
    required String gender,
    required String vehicleType,
    required String vehiclePlate,
    required File personalPhoto,
    required File nationalIdPhoto,
    required File vehicleLicense,
    required File courierLicense,
  }) async {
    try {
      final formData = FormData.fromMap({
        'full_name': fullName,
        'phone': phone,
        'password': password,
        'gender': gender,
        'vehicle_type': vehicleType,
        'vehicle_plate': vehiclePlate,
        'personal_photo': await MultipartFile.fromFile(
          personalPhoto.path,
          filename: 'personal_photo.jpg',
        ),
        'national_id_photo': await MultipartFile.fromFile(
          nationalIdPhoto.path,
          filename: 'national_id.jpg',
        ),
        'vehicle_license': await MultipartFile.fromFile(
          vehicleLicense.path,
          filename: 'vehicle_license.jpg',
        ),
        'courier_license': await MultipartFile.fromFile(
          courierLicense.path,
          filename: 'courier_license.jpg',
        ),
      });

      final response = await _dio.post(
        '/auth/register',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return AuthResponseModel.fromJson(response.data);
    } catch (e) {
      log('Register error: $e');
      rethrow;
    }
  }

  /// VERIFY PHONE OTP
  Future<OtpVerificationResponse> verifyPhoneOtp({
    required String phone,
    required String userOtp,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/verify-phone',
        data: {'phone': phone, 'user_otp': userOtp},
      );

      return OtpVerificationResponse.fromJson(response.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final message = e.response?.data?['message'];

      // ✅ treat as success
      if (status == 400 && message == 'Phone already verified') {
        return OtpVerificationResponse.fromJson({
          'status': 200,
          'message': 'Phone already verified',
          'data': {'phone': phone},
        });
      }

      // ❌ real error → rethrow
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// RESEND PHONE OTP
  Future<OtpVerificationResponse> resendPhoneOtp({
    required String phone,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/resend-phone-otp',
        data: {'phone': phone},
      );

      return OtpVerificationResponse.fromJson(response.data);
    } catch (e) {
      log('Resend OTP error: $e');
      rethrow;
    }
  }

  /// LOGIN
  Future<AuthResponseModel> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'phone': phone, 'password': password},
      );

      return AuthResponseModel.fromJson(response.data);
    } catch (e) {
      log('Login error: $e');
      rethrow;
    }
  }

  /// REFRESH TOKEN
  Future<RefreshTokenResponse> refreshToken({
    required String refreshToken,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/refresh-token',
        options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
      );

      return RefreshTokenResponse.fromJson(response.data);
    } catch (e) {
      log('Refresh token error: $e');
      rethrow;
    }
  }

  /// DELETE PROFILE
  Future<Map<String, dynamic>> deleteProfile() async {
    try {
      final response = await _dio.delete('/profile/soft-delete');
      return response.data;
    } catch (e) {
      log('Delete profile error: $e');
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
      '/auth/update-password',
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
      if (imageUrl != null) {
        if (data['imageUrl'] == null) {
          data.remove('imageUrl');
        }
        data['imageUrl'] = await MultipartFile.fromFile(imageUrl.path);
      }
      final formData = FormData.fromMap(data);

      final response = await _dio.put('/profile', data: formData);

      log(response.data.toString());
      final updatedUser = UserProfileModel.fromJson(
        response.data['updatedUser'],
      );
      log('Updated user profile: ${updatedUser.toString()}');
      return updatedUser;
    } catch (e, s) {
      log('Error parsing updated user profile', error: e, stackTrace: s);
      rethrow;
    }
  }

  /// GOOGLE SIGN IN - phone is now REQUIRED
  Future<AuthResponseModel> verifyGoogleToken({
    required String idToken,
    required String phone,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/google-login',
        data: {'id_token': idToken, 'phone': phone},
      );

      final authResponse = AuthResponseModel.fromJson(response.data);
      log('Google sign in user: ${authResponse.data.accessToken}');
      return authResponse;
    } catch (e) {
      log('Google sign in error: $e');
      rethrow;
    }
  }

  /// APPLE SIGN IN - phone is now REQUIRED
  Future<AuthResponseModel> verifyAppleToken({
    required String idToken,
    String? fullName,
    required String phone,
  }) async {
    try {
      final data = {'id_token': idToken, 'phone': phone};
      if (fullName != null) {
        data['fullname'] = fullName;
      }

      final response = await _dio.post('/auth/apple-login', data: data);

      final authResponse = AuthResponseModel.fromJson(response.data);
      log('Apple sign in user: ${authResponse.data.accessToken}');
      return authResponse;
    } catch (e) {
      log('Apple sign in error: $e');
      rethrow;
    }
  }

  /// FORGOT PASSWORD - Send OTP
  Future<ForgotPasswordResponse> forgotPassword({required String phone}) async {
    try {
      final response = await _dio.post(
        '/auth/forget-password',
        data: {'phone': phone},
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      log('Forgot password response: ${response.data}');
      return ForgotPasswordResponse.fromJson(response.data);
    } catch (e) {
      log('Forgot password error: $e');
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
        '/auth/change-password',
        data: {
          'phone': phone,
          'user_otp': userOtp,
          'new_password': newPassword,
        },
      );

      return ResetPasswordResponse.fromJson(response.data);
    } catch (e) {
      log('Reset password error: $e');
      rethrow;
    }
  }

  Future<void> logOut() async {
    try {
      final response = await _dio.post(
        '/auth/logout',
        options: Options(
          headers: {
            'Authorization':
                'Bearer ${await SecureStorageService().getToken()}',
          },
        ),
      );
    } catch (e) {
      log('Logout error: $e');
      rethrow;
    }
  }
}
