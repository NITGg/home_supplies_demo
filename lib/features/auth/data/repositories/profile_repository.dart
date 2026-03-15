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

  /// UPDATE PROFILE (basic info without photo)
  Future<UpdateProfileResponseModel> updateProfile({
    required String token,
    String? fullName,
    String? gender,
    String? lang,
    String? phone,
  }) async {
    return await _remoteDataSource.updateProfile(
      token: token,
      fullName: fullName,
      gender: gender,
      lang: lang,
      phone: phone,
    );
  }

  /// UPDATE PROFILE WITH PHOTO
  Future<UpdateProfileResponseModel> updateProfileWithPhoto({
    required String token,
    String? fullName,
    String? gender,
    String? lang,
    File? personalPhoto,
  }) async {
    return await _remoteDataSource.updateProfileWithPhoto(
      token: token,
      fullName: fullName,
      gender: gender,
      lang: lang,
      personalPhoto: personalPhoto,
    );
  }
}