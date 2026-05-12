import 'dart:io';

import '../../../../core/utils/logger.dart';
import '../../../../core/utils/secure_storage_service.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../models/auth_response_model.dart';
import '../models/user_profile_model.dart';

class AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;

  AuthRepository(this._remoteDataSource, this._storageService);

  Future<ShortAuthResponseModel> register({
    required var context,
    required String fullName,
    required String phone,
    required String password,
    String? email,
  }) async {
    final response = await _remoteDataSource.register(
      context: context,
      fullName: fullName,
      phone: phone,
      password: password,
      email: email,
    );
    await _storageService.saveToken(response.token);
    await _storageService.saveUserProfile(response.user.toJson());
    return response;
  }

  Future<ShortAuthResponseModel> login({
    required String phone,
    required String password,
    String locale = 'en',
  }) async {
    final response = await _remoteDataSource.login(
      phone: phone,
      password: password,
      locale: locale,
    );
    await _storageService.saveToken(response.token);
    await _storageService.saveUserProfile(response.user.toJson());
    return response;
  }

  Future<String?> getSavedToken() async => await _storageService.getToken();

  Future<ProfileResponseModel> getProfile(String token) async {
    final response = await _remoteDataSource.getProfile(token);
    await _storageService.saveUserProfile(response.user.toJson());
    return response;
  }

  Future<DeleteProfileResponseModel> deleteProfile(String token) async {
    try {
      final response = await _remoteDataSource.deleteProfile(token);
      await _storageService.deleteToken();
      await _storageService.deleteUserProfile();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<LongAuthResponseModel> verifyGoogleToken(String idToken) async {
    final response = await _remoteDataSource.verifyGoogleToken(idToken);
    await _storageService.saveToken(response.token);
    await _storageService.saveUserProfile(response.user.toJson());
    return response;
  }

  Future<LongAuthResponseModel> verifyAppleToken(
      String idToken,
      String? fullName,
      ) async {
    final response = await _remoteDataSource.verifyAppleToken(idToken, fullName);
    await _storageService.saveToken(response.token);
    await _storageService.saveUserProfile(response.user.toJson());
    return response;
  }

  Future<UpdateProfileResponseModel> updateProfile({
    required String token,
    String? fullName,
    String? gender,
    String? lang,
    File? personalPhoto,
  }) async {
    final response = await _remoteDataSource.updateProfile(
      token: token,
      fullName: fullName,
      gender: gender,
      lang: lang,
      personalPhoto: personalPhoto,
    );
    await _storageService.saveUserProfile(response.user.toJson());
    final savedProfile = await _storageService.getUserProfile();
    dLog('Updated and saved user profile: ${savedProfile.toString()}');
    return response;
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

  Future<void> forgotPassword({String? phone, String? email}) async {
    await _remoteDataSource.forgotPassword(phone: phone, email: email);
  }

  Future<void> resetPassword({
    required String code,
    required String password,
  }) async {
    await _remoteDataSource.resetPassword(code: code, password: password);
  }

  Future<void> resendOtp({required String phone}) async {
    await _remoteDataSource.resendOtp(phone: phone);
  }
}