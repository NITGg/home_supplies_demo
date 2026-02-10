import 'dart:developer';
import 'dart:io';

import '../../../../core/utils/secure_storage_service.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../models/auth_response_model.dart';
import '../models/user_profile_model.dart';

class AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;

  AuthRepository(
      this._remoteDataSource,
      this._storageService,
      );

  /// REGISTER
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

    // Save token and user data
    await _storageService.saveToken(response.token);
    await _storageService.saveUserProfile(response.user.toJson());

    return response;
  }

  /// LOGIN
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

    // Save token and user data
    await _storageService.saveToken(response.token);
    await _storageService.saveUserProfile(response.user.toJson());

    return response;
  }

  /// GET saved token
  Future<String?> getSavedToken() async => await _storageService.getToken();

  /// GET PROFILE
  Future<ProfileResponseModel> getProfile(String token) async {
    final response = await _remoteDataSource.getProfile(token);

    // Update saved profile
    await _storageService.saveUserProfile(response.user.toJson());

    return response;
  }

  /// DELETE profile
  Future<DeleteProfileResponseModel> deleteProfile(String token) async {
    try {
      final response = await _remoteDataSource.deleteProfile(token);

      // Clear stored data
      await _storageService.deleteToken();
      await _storageService.deleteUserProfile();

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// VERIFY GOOGLE TOKEN
  Future<LongAuthResponseModel> verifyGoogleToken(String idToken) async {
    final response = await _remoteDataSource.verifyGoogleToken(idToken);

    // Save token & profile
    await _storageService.saveToken(response.token);
    await _storageService.saveUserProfile(response.user.toJson());

    return response;
  }

  /// VERIFY APPLE TOKEN
  Future<LongAuthResponseModel> verifyAppleToken(
      String idToken,
      String? fullName,
      ) async {
    final response = await _remoteDataSource.verifyAppleToken(
      idToken,
      fullName,
    );

    // Save token & profile
    await _storageService.saveToken(response.token);
    await _storageService.saveUserProfile(response.user.toJson());

    return response;
  }

  /// UPDATE PROFILE
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

    // Save updated profile
    await _storageService.saveUserProfile(response.user.toJson());

    final savedProfile = await _storageService.getUserProfile();
    log('Updated and saved user profile: ${savedProfile.toString()}');

    return response;
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
}