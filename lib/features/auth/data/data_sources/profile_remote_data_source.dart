import 'dart:io';

import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/auth_response_model.dart';
import '../models/user_profile_model.dart';
import '../models/vehicles_model.dart';

class ProfileRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  /// GET PROFILE
  Future<ProfileResponseModel> getProfile() async {
    try {
      final response = await _dio.get(
        '/profile/get-profile?lang=${LocaleManager.currentLocale}',
      );
      return ProfileResponseModel.fromJson(response.data);
    } catch (e) {
      dLog('Get profile error: $e');
      rethrow;
    }
  }

  /// GET AVAILABLE VEHICLES
  Future<AvailableVehiclesResponseModel> fetchAvailableVehicles() async {
    try {
      final response = await _dio.get('/auth/available-vehicles');
      dLog('Available vehicles response: ${response.data}');
      return AvailableVehiclesResponseModel.fromJson(response.data);
    } catch (e) {
      dLog('Fetch available vehicles error: $e');
      rethrow;
    }
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
    try {
      final Map<String, dynamic> data = {};
      if (fullName != null) data['full_name'] = fullName;
      if (gender != null) data['gender'] = gender;
      if (vehicleId != null) data['vehicle_id'] = vehicleId;
      if (vehiclePlate != null) data['vehicle_plate'] = vehiclePlate;
      if (lang != null) data['language'] = lang;
      if (extraPhones != null) data['extra_phones'] = extraPhones;

      final response = await _dio.patch(
        '/profile/update-profile?lang=${LocaleManager.currentLocale.toUpperCase()}',
        data: data,
      );

      dLog('Update profile response: ${response.data}');
      return UpdateProfileResponseModel.fromJson(response.data);
    } catch (e) {
      dLog('Update profile error: $e');
      rethrow;
    }
  }

  /// UPDATE DOCUMENTS
  ///
  /// Every document is sent as separate front + back files, matching the
  /// API field names exactly:
  ///   national_id_photo_front / national_id_photo_back
  ///   vehicle_license_front   / vehicle_license_back
  ///   courier_license_front   / courier_license_back
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
    try {
      final formData = FormData();

      Future<void> addFile(String field, File file, String filename) async {
        formData.files.add(MapEntry(
          field,
          await MultipartFile.fromFile(file.path, filename: filename),
        ));
      }

      if (personalPhoto != null) {
        await addFile('personal_photo', personalPhoto, 'personal_photo.jpg');
      }

      // ── National ID ──────────────────────────────────────────────────────
      if (nationalIdPhotoFront != null) {
        await addFile(
            'national_id_photo_front', nationalIdPhotoFront, 'national_id_front.jpg');
      }
      if (nationalIdPhotoBack != null) {
        await addFile(
            'national_id_photo_back', nationalIdPhotoBack, 'national_id_back.jpg');
      }

      // ── Vehicle license ──────────────────────────────────────────────────
      if (vehicleLicenseFront != null) {
        await addFile(
            'vehicle_license_front', vehicleLicenseFront, 'vehicle_license_front.jpg');
      }
      if (vehicleLicenseBack != null) {
        await addFile(
            'vehicle_license_back', vehicleLicenseBack, 'vehicle_license_back.jpg');
      }

      // ── Courier license ──────────────────────────────────────────────────
      if (courierLicenseFront != null) {
        await addFile(
            'courier_license_front', courierLicenseFront, 'courier_license_front.jpg');
      }
      if (courierLicenseBack != null) {
        await addFile(
            'courier_license_back', courierLicenseBack, 'courier_license_back.jpg');
      }

      // ── Criminal record ──────────────────────────────────────────────────
      if (criminalRecord != null) {
        await addFile(
            'courier_criminal_record', criminalRecord, 'criminal_record.jpg');
      }

      final response = await _dio.patch(
        '/profile/update-documents?lang=${LocaleManager.currentLocale}',
        data: formData,
      );

      return UpdateProfileResponseModel.fromJson(response.data);
    } catch (e) {
      dLog('Update documents error: $e');
      rethrow;
    }
  }

  // ── CHANGE PHONE ────────────────────────────────────────────────────────────

  /// Initiate phone change — sends OTP to old phone (if exists) and new phone.
  Future<String> requestChangePhone({
    required String newPhone,
    String? currentPhone,
  }) async {
    try {
      final response = await _dio.patch(
        '/auth/change-phone?lang=${LocaleManager.currentLocale}',
        data: {
          'new_phone': newPhone,
          if (currentPhone != null) 'current_phone': currentPhone,
        },
      );
      dLog('requestChangePhone response: ${response.data}');
      return response.data['message'] as String? ?? '';
    } catch (e) {
      dLog('requestChangePhone error: $e');
      rethrow;
    }
  }

  /// Verify OTP(s) for phone change (verify_type: CHANGE_PHONE).
  Future<VerifyOtpResponse> verifyChangePhone({
    required String newPhone,
    required String newOtp,
    String? oldPhone,
    String? oldOtp,
  }) async {
    try {
      dLog('requestChangePhone: $newPhone, $newOtp, $oldPhone, $oldOtp');
      final response = await _dio.post(
        '/auth/verify-otp?lang=${LocaleManager.currentLocale}',
        data: {
          'phone': oldPhone,
          'user_otp': oldOtp,
          'verify_type': 'CHANGE_PHONE',
          if (oldPhone != null) 'second_phone': newPhone,
          if (oldOtp != null) 'second_user_otp': newOtp,
        },
      );
      return VerifyOtpResponse.fromJson(response.data);
    } catch (e) {
      dLog('verifyChangePhone error: $e');
      rethrow;
    }
  }

  /// Resend OTP for phone change.
  Future<VerifyOtpResponse> resendChangePhoneOtp({
    required String newPhone,
    String? oldPhone,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/resend-otp?lang=${LocaleManager.currentLocale}',
        data: {
          'phone': newPhone,
          'verify_type': 'CHANGE_PHONE',
          if (oldPhone != null) 'second_phone': oldPhone,
        },
      );
      return VerifyOtpResponse.fromJson(response.data);
    } catch (e) {
      dLog('resendChangePhoneOtp error: $e');
      rethrow;
    }
  }
}