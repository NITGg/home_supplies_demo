import 'dart:io';

import '../data_sources/profile_remote_data_source.dart';
import '../models/auth_response_model.dart';
import '../models/user_profile_model.dart';
import '../models/vehicles_model.dart';

class ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;

  ProfileRepository(this._remoteDataSource);

  /// GET PROFILE
  Future<ProfileResponseModel> getProfile() async {
    return await _remoteDataSource.getProfile();
  }

  /// GET AVAILABLE VEHICLES
  Future<AvailableVehiclesResponseModel> fetchAvailableVehicles() async {
    return await _remoteDataSource.fetchAvailableVehicles();
  }

  /// UPDATE PROFILE
  Future<UpdateProfileResponseModel> updateProfile({
    String? fullName,
    String? gender,
    String? vehicleId,
    String? vehiclePlate,
    String? lang,
    String? extraPhones,
  }) async {
    return await _remoteDataSource.updateProfile(
      fullName: fullName,
      gender: gender,
      vehicleId: vehicleId,
      vehiclePlate: vehiclePlate,
      lang: lang,
      extraPhones: extraPhones,
    );
  }

  /// UPDATE DOCUMENTS
  ///
  /// Passes front + back files separately for each document type.
  /// All parameters are optional — only non-null files are sent to the API.
  Future<UpdateProfileResponseModel> updateDocuments({
    File? personalPhoto,
    // National ID
    File? nationalIdPhotoFront,
    File? nationalIdPhotoBack,
    // Vehicle license
    File? vehicleLicenseFront,
    File? vehicleLicenseBack,
    // Courier license
    File? courierLicenseFront,
    File? courierLicenseBack,
    // Criminal record
    File? criminalRecord,
  }) async {
    return await _remoteDataSource.updateDocuments(
      personalPhoto: personalPhoto,
      nationalIdPhotoFront: nationalIdPhotoFront,
      nationalIdPhotoBack: nationalIdPhotoBack,
      vehicleLicenseFront: vehicleLicenseFront,
      vehicleLicenseBack: vehicleLicenseBack,
      courierLicenseFront: courierLicenseFront,
      courierLicenseBack: courierLicenseBack,
      criminalRecord: criminalRecord,
    );
  }

  Future<String> requestChangePhone({
    required String newPhone,
    String? currentPhone,
  }) async {
    return await _remoteDataSource.requestChangePhone(
      newPhone: newPhone,
      currentPhone: currentPhone,
    );
  }

  Future<VerifyOtpResponse> verifyChangePhone({
    required String newPhone,
    required String newOtp,
    String? oldPhone,
    String? oldOtp,
  }) async {
    return await _remoteDataSource.verifyChangePhone(
      newPhone: newPhone,
      newOtp: newOtp,
      oldPhone: oldPhone,
      oldOtp: oldOtp,
    );
  }

  Future<VerifyOtpResponse> resendChangePhoneOtp({
    required String newPhone,
    String? oldPhone,
  }) async {
    return await _remoteDataSource.resendChangePhoneOtp(
      newPhone: newPhone,
      oldPhone: oldPhone,
    );
  }
}