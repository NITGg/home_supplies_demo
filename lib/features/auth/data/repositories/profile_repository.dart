import 'dart:io';

import '../data_sources/profile_remote_data_source.dart';
import '../models/user_profile_model.dart';

class ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;

  ProfileRepository(this._remoteDataSource);

  /// GET PROFILE
  Future<ProfileResponseModel> getProfile() async {
    return await _remoteDataSource.getProfile();
  }

  /// UPDATE PROFILE
  Future<UpdateProfileResponseModel> updateProfile({
    String? fullName,
    String? gender,
    String? vehicleType,
    String? vehiclePlate,
  }) async {
    return await _remoteDataSource.updateProfile(
      fullName: fullName,
      gender: gender,
      vehicleType: vehicleType,
      vehiclePlate: vehiclePlate,
    );
  }

  /// UPDATE DOCUMENTS
  Future<UpdateProfileResponseModel> updateDocuments({
    File? personalPhoto,
    File? nationalIdPhoto,
    File? vehicleLicense,
    File? courierLicense,
  }) async {
    return await _remoteDataSource.updateDocuments(
      personalPhoto: personalPhoto,
      nationalIdPhoto: nationalIdPhoto,
      vehicleLicense: vehicleLicense,
      courierLicense: courierLicense,
    );
  }

  /// GET BADGE PROGRESS
  Future<BadgeProgressResponseModel> getBadgeProgress() async {
    return await _remoteDataSource.getBadgeProgress();
  }
}