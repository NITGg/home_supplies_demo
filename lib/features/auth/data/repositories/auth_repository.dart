import 'dart:io';

import '../../../../core/utils/secure_storage_service.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../models/auth_response_model.dart';
import 'package:flutter/material.dart';

import '../models/vehicles_model.dart';

class AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;

  AuthRepository(this._remoteDataSource, this._storageService);

  /// GET AVAILABLE VEHICLES
  Future<AvailableVehiclesResponseModel> fetchAvailableVehicles() async {
    return await _remoteDataSource.fetchAvailableVehicles();
  }

  /// REGISTER
  Future<AuthResponseModel> register({
    required BuildContext context,
    required String fullName,
    required String phone,
    required String password,
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
    final response = await _remoteDataSource.register(
      context: context,
      fullName: fullName,
      phone: phone,
      password: password,
      gender: gender,
      vehicleId: vehicleId,
      vehiclePlate: vehiclePlate,
      nationalId: nationalId,
      personalPhoto: personalPhoto,
      nationalIdPhotoFront: nationalIdPhotoFront,
      nationalIdPhotoBack: nationalIdPhotoBack,
      vehicleLicenseFront: vehicleLicenseFront,
      vehicleLicenseBack: vehicleLicenseBack,
      courierLicenseFront: courierLicenseFront,
      courierLicenseBack: courierLicenseBack,
      criminalRecord: criminalRecord,
    );

    await _saveAuthData(response.data);
    return response;
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
    final response = await _remoteDataSource.googleRegister(
      idToken: idToken,
      fullName: fullName,
      phone: phone,
      gender: gender,
      vehicleId: vehicleId,
      nationalId: nationalId,
      vehiclePlate: vehiclePlate,
      personalPhoto: personalPhoto,
      nationalIdPhotoFront: nationalIdPhotoFront,
      nationalIdPhotoBack: nationalIdPhotoBack,
      vehicleLicenseFront: vehicleLicenseFront,
      vehicleLicenseBack: vehicleLicenseBack,
      courierLicenseFront: courierLicenseFront,
      courierLicenseBack: courierLicenseBack,
      criminalRecord: criminalRecord,
    );

    await _saveAuthData(response.data);
    return response;
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
    final response = await _remoteDataSource.appleRegister(
      idToken: idToken,
      fullName: fullName,
      phone: phone,
      gender: gender,
      vehicleId: vehicleId,
      nationalId: nationalId,
      vehiclePlate: vehiclePlate,
      personalPhoto: personalPhoto,
      nationalIdPhotoFront: nationalIdPhotoFront,
      nationalIdPhotoBack: nationalIdPhotoBack,
      vehicleLicenseFront: vehicleLicenseFront,
      vehicleLicenseBack: vehicleLicenseBack,
      courierLicenseFront: courierLicenseFront,
      courierLicenseBack: courierLicenseBack,
      criminalRecord: criminalRecord,
    );

    await _saveAuthData(response.data);
    return response;
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

    await _storageService.saveToken(response.data.accessToken);
    return response.data.accessToken;
  }

  Future<String?> getSavedToken() async => await _storageService.getToken();

  Future<String?> getSavedRefreshToken() async =>
      await _storageService.getRefreshToken();

  Future<Map<String, dynamic>> deleteProfile() async {
    return await _remoteDataSource.deleteProfile();
  }

  Future<AuthResponseModel> verifyGoogleToken({required String idToken}) async {
    final response = await _remoteDataSource.verifyGoogleToken(
      idToken: idToken,
    );
    await _saveAuthData(response.data);
    return response;
  }

  Future<AuthResponseModel> verifyAppleToken({
    required String idToken,
    String? fullName,
  }) async {
    final response = await _remoteDataSource.verifyAppleToken(
      idToken: idToken,
      fullName: fullName,
    );
    await _saveAuthData(response.data);
    return response;
  }

  Future<Map<String, dynamic>> linkGoogle({required String idToken}) async {
    return await _remoteDataSource.linkGoogle(idToken: idToken);
  }

  Future<Map<String, dynamic>> linkApple({
    required String idToken,
    String? fullName,
  }) async {
    return await _remoteDataSource.linkApple(
      idToken: idToken,
      fullName: fullName,
    );
  }

  Future<ForgotPasswordResponse> forgotPassword({required String phone}) async {
    return await _remoteDataSource.forgotPassword(phone: phone);
  }

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

  Future<void> logout() async {
    await _remoteDataSource.logOut();
    await _storageService.deleteToken();
    await _storageService.deleteRefreshToken();
    await _storageService.deleteUserProfile();
  }

  Future<VerifyOtpResponse> verifyOtp({
    required String phone,
    required String userOtp,
    required String verifyType,
    String? newPassword,
    String? secondPhone,
    String? secondUserOtp,
  }) async {
    final result = await _remoteDataSource.verifyOtp(
      phone: phone,
      userOtp: userOtp,
      verifyType: verifyType,
      newPassword: newPassword,
      secondPhone: secondPhone,
      secondUserOtp: secondUserOtp,
    );
    if (result.accessToken != null && result.refreshToken != null) {
      await _saveAuthData(
        AuthData.fromTokens(
          accessToken: result.accessToken!,
          refreshToken: result.refreshToken!,
        ),
      );
    }
    return result;
  }

  Future<VerifyOtpResponse> resendOtp({
    required String phone,
    required String verifyType,
    String? secondPhone,
  }) async {
    return await _remoteDataSource.resendOtp(
      phone: phone,
      verifyType: verifyType,
      secondPhone: secondPhone,
    );
  }

  Future<void> _saveAuthData(AuthData authData) async {
    await _storageService.saveToken(authData.accessToken);
    await _storageService.saveRefreshToken(authData.refreshToken);
  }
}