import 'dart:io';

import '../../../../core/utils/secure_storage_service.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../models/auth_response_model.dart';
import 'package:flutter/material.dart';


class AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;

  AuthRepository(this._remoteDataSource, this._storageService);

  /// REGISTER
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
    final response = await _remoteDataSource.register(
      context: context,
      fullName: fullName,
      phone: phone,
      password: password,
      gender: gender,
      vehicleType: vehicleType,
      vehiclePlate: vehiclePlate,
      personalPhoto: personalPhoto,
      nationalIdPhoto: nationalIdPhoto,
      vehicleLicense: vehicleLicense,
      courierLicense: courierLicense,
    );

    // Save tokens and user data
    await _saveAuthData(response.data);

    return response;
  }

  /// VERIFY PHONE OTP
  Future<OtpVerificationResponse> verifyPhoneOtp({
    required String phone,
    required String userOtp,
  }) async {
    return await _remoteDataSource.verifyPhoneOtp(
      phone: phone,
      userOtp: userOtp,
    );
  }

  /// RESEND PHONE OTP
  Future<OtpVerificationResponse> resendPhoneOtp({
    required String phone,
  }) async {
    return await _remoteDataSource.resendPhoneOtp(phone: phone);
  }

  /// LOGIN
  Future<AuthResponseModel> login({
    required String phone,
    required String password,
  }) async {
    final response = await _remoteDataSource.login(
      phone: phone,
      password: password,
    );

    // Save tokens and user data
    await _saveAuthData(response.data);

    return response;
  }

  /// REFRESH TOKEN
  Future<String> refreshAccessToken() async {
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('No refresh token available');
    }

    final response = await _remoteDataSource.refreshToken(
      refreshToken: refreshToken,
    );

    // Save new access token
    await _storageService.saveToken(response.data.accessToken);

    return response.data.accessToken;
  }

  /// GET saved access token
  Future<String?> getSavedToken() async => await _storageService.getToken();

  /// GET saved refresh token
  Future<String?> getSavedRefreshToken() async =>
      await _storageService.getRefreshToken();

  /// DELETE profile
  Future<Map<String, dynamic>> deleteProfile() async {
    try {
      return await _remoteDataSource.deleteProfile();
    } catch (e) {
      rethrow;
    }
  }

  /// VERIFY GOOGLE TOKEN - phone is now REQUIRED
  Future<AuthResponseModel> verifyGoogleToken({
    required String idToken,
    required String phone,
  }) async {
    final response = await _remoteDataSource.verifyGoogleToken(
      idToken: idToken,
      phone: phone,
    );

    // Save tokens and user data
    await _saveAuthData(response.data);

    return response;
  }

  /// VERIFY APPLE TOKEN - phone is now REQUIRED
  Future<AuthResponseModel> verifyAppleToken({
    required String idToken,
    String? fullName,
    required String phone,
  }) async {
    final response = await _remoteDataSource.verifyAppleToken(
      idToken: idToken,
      fullName: fullName,
      phone: phone,
    );

    // Save tokens and user data
    await _saveAuthData(response.data);

    return response;
  }

  /// FORGOT PASSWORD - Send OTP
  Future<ForgotPasswordResponse> forgotPassword({required String phone}) async {
    return await _remoteDataSource.forgotPassword(phone: phone);
  }

  /// RESET PASSWORD with OTP
  Future<ResetPasswordResponse> resetPassword({
    required String phone,
    required String userOtp,
    required String newPassword,
  }) async {
    return await _remoteDataSource.resetPassword(
      phone: phone,
      userOtp: userOtp,
      newPassword: newPassword,
    );
  }

  /// CHANGE PASSWORD
  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
    required var context,
  }) async {
    await _remoteDataSource.changePassword(
      context: context,
      token: token,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  /// LOGOUT
  Future<void> logout() async {
    await _remoteDataSource.logOut();
    await _storageService.deleteToken();
    await _storageService.deleteRefreshToken();
    await _storageService.deleteUserProfile();
  }

  /// Helper method to save auth data
  Future<void> _saveAuthData(AuthData authData) async {
    await _storageService.saveToken(authData.accessToken);
    await _storageService.saveRefreshToken(authData.refreshToken);
  }
}
