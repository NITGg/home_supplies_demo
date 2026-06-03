import 'dart:io';

import '../data_sources/profile_remote_data_source.dart';
import '../models/user_profile_model.dart';

class ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;

  ProfileRepository(this._remoteDataSource);

  /// GET PROFILE
  Future<ProfileResponseModel> getProfile(String token) async {
    return await _remoteDataSource.getProfile(token);
  }


  /// Sends OTP to both old and new contact values (phone or email).
  Future<Map<String, dynamic>> changeContactInfo({
    required String token,
    required String type,
    required String newValue,
  }) async {
    return await _remoteDataSource.changeContactInfo(
      token: token,
      type: type,
      newValue: newValue,
    );
  }

  /// UPDATE PROFILE (basic info without photo)
  Future<UpdateProfileResponseModel> updateProfile({
    required String token,
    String? fullName,
    String? gender,
    String? lang,
    String? phone,
    String? extraPhones,
  }) async {
    return await _remoteDataSource.updateProfile(
      token: token,
      fullName: fullName,
      gender: gender,
      lang: lang,
      phone: phone,
      extraPhones: extraPhones,
    );
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
    return await _remoteDataSource.updateProfileWithPhoto(
      token: token,
      fullName: fullName,
      gender: gender,
      lang: lang,
      personalPhoto: personalPhoto,
      extraPhones: extraPhones,
    );
  }

  Future<Map<String, dynamic>> verifyContactChange({
    required String token,
    required String oldCode,
    required String newCode,
  }) async {
    return await _remoteDataSource.verifyContactChange(
      token: token,
      oldCode: oldCode,
      newCode: newCode,
    );
  }
}