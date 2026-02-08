import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/features/auth/manager/profile_states.dart';

import '../data/models/user_profile_model.dart';
import '../data/repositories/profile_repository.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository _repository;
  UserProfileModel? _currentProfile;
  BadgeProgressData? _badgeProgress;

  ProfileCubit(this._repository) : super(ProfileInitial());

  // Getters for current data
  UserProfileModel? get currentProfile => _currentProfile;
  BadgeProgressData? get badgeProgress => _badgeProgress;

  /// FETCH PROFILE
  Future<void> fetchProfile() async {
    emit(ProfileLoading());
    try {
      final result = await _repository.getProfile();
      _currentProfile = result.data.user;
      emit(ProfileLoaded(profile: result.data.user));
    } on DioException catch (e) {
      log('ProfileCubit fetchProfile DioException: $e');
      log('Response data: ${e.response?.data}');
      log('Status code: ${e.response?.statusCode}');
      emit(ProfileFailure(_extractErrorMessage(e)));
    } catch (e) {
      log('ProfileCubit fetchProfile error: $e');
      emit(ProfileFailure(_extractErrorMessage(e)));
    }
  }

  /// UPDATE PROFILE
  Future<void> updateProfile({
    String? fullName,
    String? gender,
    String? vehicleType,
    String? vehiclePlate,
  }) async {
    emit(ProfileLoading());
    try {
      final result = await _repository.updateProfile(
        fullName: fullName,
        gender: gender,
        vehicleType: vehicleType,
        vehiclePlate: vehiclePlate,
      );

      // Refresh profile data after update
      await fetchProfile();

      emit(ProfileUpdateSuccess(message: result.message));
    } on DioException catch (e) {
      log('ProfileCubit updateProfile DioException: $e');
      log('Response data: ${e.response?.data}');
      log('Status code: ${e.response?.statusCode}');
      emit(ProfileFailure(_extractErrorMessage(e)));
    } catch (e) {
      log('ProfileCubit updateProfile error: $e');
      emit(ProfileFailure(_extractErrorMessage(e)));
    }
  }

  /// UPDATE DOCUMENTS
  Future<void> updateDocuments({
    File? personalPhoto,
    File? nationalIdPhoto,
    File? vehicleLicense,
    File? courierLicense,
  }) async {
    log('ProfileCubit updateDocuments called');
    log('personalPhoto: ${personalPhoto?.path}');
    log('nationalIdPhoto: ${nationalIdPhoto?.path}');
    log('vehicleLicense: ${vehicleLicense?.path}');
    log('courierLicense: ${courierLicense?.path}');

    emit(ProfileLoading());
    try {
      log('Calling repository.updateDocuments...');
      final result = await _repository.updateDocuments(
        personalPhoto: personalPhoto,
        nationalIdPhoto: nationalIdPhoto,
        vehicleLicense: vehicleLicense,
        courierLicense: courierLicense,
      );

      log('Update documents successful: ${result.message}');

      // Refresh profile data after update
      log('Fetching updated profile...');
      await fetchProfile();

      emit(ProfileUpdateSuccess(message: result.message));
    } on DioException catch (e) {
      log('ProfileCubit updateDocuments DioException: $e');
      log('DioException type: ${e.type}');
      log('Response data: ${e.response?.data}');
      log('Status code: ${e.response?.statusCode}');
      log('Request data: ${e.requestOptions.data}');
      log('Request headers: ${e.requestOptions.headers}');
      emit(ProfileFailure(_extractErrorMessage(e)));
    } catch (e, stackTrace) {
      log('ProfileCubit updateDocuments error: $e');
      log('Stack trace: $stackTrace');
      emit(ProfileFailure(_extractErrorMessage(e)));
    }
  }

  /// FETCH BADGE PROGRESS
  Future<void> fetchBadgeProgress() async {
    emit(BadgeProgressLoading());
    try {
      final result = await _repository.getBadgeProgress();
      _badgeProgress = result.data;
      emit(BadgeProgressLoaded(badgeProgress: result.data));
    } on DioException catch (e) {
      log('ProfileCubit fetchBadgeProgress DioException: $e');
      log('Response data: ${e.response?.data}');
      log('Status code: ${e.response?.statusCode}');
      emit(ProfileFailure(_extractErrorMessage(e)));
    } catch (e) {
      log('ProfileCubit fetchBadgeProgress error: $e');
      emit(ProfileFailure(_extractErrorMessage(e)));
    }
  }

  /// Helper function to extract error messages
  String _extractErrorMessage(dynamic e) {
    String message = 'حدث خطأ غير متوقع';

    if (e is DioException) {
      try {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          message = data['message'];
        } else if (data is String) {
          message = data;
        }
      } catch (_) {}
    } else {
      message = e.toString();
    }

    return message;
  }

  void reset() {
    emit(ProfileInitial());
  }
}