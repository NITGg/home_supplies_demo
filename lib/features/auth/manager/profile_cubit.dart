import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/auth/manager/profile_states.dart';
import 'package:tawreedat_go/core/utils/secure_storage_service.dart';

import '../../../core/utils/extract_error_message.dart';
import '../data/models/user_profile_model.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/auth_repository.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository _profileRepository;
  final AuthRepository _authRepository;
  UserProfileModel? _currentProfile;

  ProfileCubit(this._profileRepository, this._authRepository)
      : super(ProfileInitial()) {
    _loadCachedProfile();
  }

  // Getters for current data
  UserProfileModel? get currentProfile => _currentProfile;

  /// Load cached profile from storage on initialization
  Future<void> _loadCachedProfile() async {
    try {
      final profileData = await _authRepository.getSavedToken();
      if (profileData != null) {
        final secureStorage = SecureStorageService();
        final cachedProfile = await secureStorage.getUserProfile();
        if (cachedProfile != null) {
          _currentProfile = UserProfileModel.fromJson(cachedProfile);
          emit(ProfileLoaded(profile: _currentProfile!));
          log('ProfileCubit: Loaded cached profile');
        }
      }
    } catch (e) {
      log('ProfileCubit: Error loading cached profile: $e');
      // Don't emit error state, just continue without cached data
    }
  }

  /// FETCH PROFILE
  Future<void> fetchProfile() async {
    // Don't show loading if we already have a profile (for refresh)
    if (_currentProfile == null) {
      emit(ProfileLoading());
    }

    try {
      final token = await _authRepository.getSavedToken();
      if (token == null || token.isEmpty) {
        log('ProfileCubit: No token found');
        emit(ProfileFailure('لا يوجد رمز مصادقة'));
        return;
      }

      log('ProfileCubit: Fetching profile with token');
      final result = await _authRepository.getProfile(token);
      _currentProfile = result.user;
      emit(ProfileLoaded(profile: result.user));
      log('ProfileCubit: Profile loaded successfully');
    } on DioException catch (e) {
      log('ProfileCubit fetchProfile DioException: $e');
      log('Response data: ${e.response?.data}');
      log('Status code: ${e.response?.statusCode}');
      emit(ProfileFailure(extractErrorMessage(e)));
    } catch (e, stackTrace) {
      log('ProfileCubit fetchProfile error: $e');
      log('Stack trace: $stackTrace');
      emit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  /// UPDATE PROFILE (without photo)
  Future<void> updateProfile({
    String? fullName,
    String? gender,
    String? lang,
  }) async {
    emit(ProfileLoading());
    try {
      final token = await _authRepository.getSavedToken();
      if (token == null || token.isEmpty) {
        emit(ProfileFailure('لا يوجد رمز مصادقة'));
        return;
      }

      final result = await _profileRepository.updateProfile(
        token: token,
        fullName: fullName,
        gender: gender,
        lang: lang,
      );

      // Update local profile
      _currentProfile = result.user;

      // Refresh profile data after update
      await fetchProfile();

      emit(ProfileUpdateSuccess(message: result.message));
    } on DioException catch (e) {
      log('ProfileCubit updateProfile DioException: $e');
      log('Response data: ${e.response?.data}');
      log('Status code: ${e.response?.statusCode}');
      emit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      log('ProfileCubit updateProfile error: $e');
      emit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  /// UPDATE PROFILE WITH PHOTO
  Future<void> updateProfileWithPhoto({
    String? fullName,
    String? gender,
    String? lang,
    File? personalPhoto,
  }) async {
    log('ProfileCubit updateProfileWithPhoto called');
    log('fullName: $fullName');
    log('gender: $gender');
    log('lang: $lang');
    log('personalPhoto: ${personalPhoto?.path}');

    emit(ProfileLoading());
    try {
      final token = await _authRepository.getSavedToken();
      if (token == null || token.isEmpty) {
        emit(ProfileFailure('لا يوجد رمز مصادقة'));
        return;
      }

      log('Calling repository.updateProfileWithPhoto...');
      final result = await _profileRepository.updateProfileWithPhoto(
        token: token,
        fullName: fullName,
        gender: gender,
        lang: lang,
        personalPhoto: personalPhoto,
      );

      log('Update profile with photo successful: ${result.message}');

      // Update local profile
      _currentProfile = result.user;

      // Refresh profile data after update
      log('Fetching updated profile...');
      await fetchProfile();

      emit(ProfileUpdateSuccess(message: result.message));
    } on DioException catch (e) {
      log('ProfileCubit updateProfileWithPhoto DioException: $e');
      log('DioException type: ${e.type}');
      log('Response data: ${e.response?.data}');
      log('Status code: ${e.response?.statusCode}');
      log('Request data: ${e.requestOptions.data}');
      log('Request headers: ${e.requestOptions.headers}');
      emit(ProfileFailure(extractErrorMessage(e)));
    } catch (e, stackTrace) {
      log('ProfileCubit updateProfileWithPhoto error: $e');
      log('Stack trace: $stackTrace');
      emit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  void reset() {
    _currentProfile = null;
    emit(ProfileInitial());
  }
}