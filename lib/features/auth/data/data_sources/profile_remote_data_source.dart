import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/user_profile_model.dart';

class ProfileRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  /// GET PROFILE
  Future<ProfileResponseModel> getProfile() async {
    try {
      final response = await _dio.get('/profile/get-profile');

      log('Get profile response: ${response.data}');
      return ProfileResponseModel.fromJson(response.data);
    } catch (e) {
      log('Get profile error: $e');
      rethrow;
    }
  }

  /// UPDATE PROFILE
  Future<UpdateProfileResponseModel> updateProfile({
    String? fullName,
    String? gender,
    String? vehicleType,
    String? vehiclePlate,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (fullName != null) data['full_name'] = fullName;
      if (gender != null) data['gender'] = gender;
      if (vehicleType != null) data['vehicle_type'] = vehicleType;
      if (vehiclePlate != null) data['vehicle_plate'] = vehiclePlate;

      final response = await _dio.patch('/profile/update-profile', data: data);

      log('Update profile response: ${response.data}');
      return UpdateProfileResponseModel.fromJson(response.data);
    } catch (e) {
      log('Update profile error: $e');
      rethrow;
    }
  }

  /// UPDATE DOCUMENTS (personal photo and national ID)
  Future<UpdateProfileResponseModel> updateDocuments({
    File? personalPhoto,
    File? nationalIdPhoto,
    File? vehicleLicense,
    File? courierLicense,
  }) async {
    try {
      final formData = FormData();

      if (personalPhoto != null) {
        formData.files.add(MapEntry(
          'personal_photo',
          await MultipartFile.fromFile(personalPhoto.path),
        ));
      }

      if (nationalIdPhoto != null) {
        formData.files.add(MapEntry(
          'national_id_photo',
          await MultipartFile.fromFile(nationalIdPhoto.path),
        ));
      }

      if (vehicleLicense != null) {
        formData.files.add(MapEntry(
          'vehicle_license',
          await MultipartFile.fromFile(vehicleLicense.path),
        ));
      }

      if (courierLicense != null) {
        formData.files.add(MapEntry(
          'courier_license',
          await MultipartFile.fromFile(courierLicense.path),
        ));
      }

      final response = await _dio.patch(
        '/profile/update-documents',
        data: formData,
      );

      log('Update documents response: ${response.data}');
      return UpdateProfileResponseModel.fromJson(response.data);
    } catch (e) {
      log('Update documents error: $e');
      rethrow;
    }
  }

  /// GET BADGE PROGRESS
  Future<BadgeProgressResponseModel> getBadgeProgress() async {
    try {
      final response = await _dio.get('/profile/badge-progress');

      log('Get badge progress response: ${response.data}');
      return BadgeProgressResponseModel.fromJson(response.data);
    } catch (e) {
      log('Get badge progress error: $e');
      rethrow;
    }
  }
}
