import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/auth/manager/profile_states.dart';
import 'package:tawreedat_go/core/utils/secure_storage_service.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/social_auth_service.dart';
import '../../../l10n/manager/locale_cubit.dart';
import '../data/models/user_profile_model.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../../../core/utils/safe_emit_mixin.dart';

class ProfileCubit extends Cubit<ProfileState> with SafeEmitMixin<ProfileState> {
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
          safeEmit(ProfileLoaded(profile: _currentProfile!));
          dLog('ProfileCubit: Loaded cached profile');
        }
      }
    } catch (e) {
      dLog('ProfileCubit: Error loading cached profile: $e');
      // Don't emit error state, just continue without cached data
    }
  }

  /// FETCH PROFILE
  Future<void> fetchProfile() async {
    // Don't show loading if we already have a profile (for refresh)
    if (_currentProfile == null) {
      safeEmit(ProfileLoading());
    }

    try {
      final token = await _authRepository.getSavedToken();
      if (token == null || token.isEmpty) {
        dLog('ProfileCubit: No token found');
        safeEmit(ProfileFailure('لا يوجد رمز مصادقة'));
        return;
      }

      dLog('ProfileCubit: Fetching profile with token');
      final result = await _profileRepository.getProfile(token);
      _currentProfile = result.user;
      dLog('ProfileCubit: personalPhoto=${result.user.personalPhoto} loginType=${result.user.loginType}');
      await SecureStorageService().saveUserProfile(result.user.toJson());
      // Sync local locale to match profile lang (no backend call).
      await LocaleManager.syncFromProfile(_currentProfile?.lang??'AR');
      safeEmit(ProfileLoaded(profile: result.user));
      dLog('ProfileCubit: Profile loaded successfully');
    } on DioException catch (e) {
      dLog('ProfileCubit fetchProfile DioException: $e');
      dLog('Response data: ${e.response?.data}');
      dLog('Status code: ${e.response?.statusCode}');
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    } catch (e, stackTrace) {
      dLog('ProfileCubit fetchProfile error: $e');
      dLog('Stack trace: $stackTrace');
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  /// UPDATE PROFILE (without photo)
  Future<void> updateProfile({
    String? fullName,
    String? gender,
    String? lang,
    String? phone,
    String? extraPhones, // 👈 new
  }) async {
    safeEmit(ProfileLoading());
    try {
      final token = await _authRepository.getSavedToken();
      if (token == null || token.isEmpty) {
        safeEmit(ProfileFailure('لا يوجد رمز مصادقة'));
        return;
      }

      final result = await _profileRepository.updateProfile(
        token: token,
        fullName: fullName,
        gender: gender,
        lang: lang,
        phone: phone,
        extraPhones: extraPhones, // 👈 new
      );

      _currentProfile = result.user;
      await fetchProfile();
      safeEmit(ProfileUpdateSuccess(message: result.message));
    } on DioException catch (e) {
      dLog('ProfileCubit updateProfile DioException: $e');
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      dLog('ProfileCubit updateProfile error: $e');
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  /// UPDATE PROFILE WITH PHOTO
  Future<void> updateProfileWithPhoto({
    String? fullName,
    String? gender,
    String? lang,
    File? personalPhoto,
    String? extraPhones,
  }) async {
    safeEmit(ProfileLoading());
    try {
      final token = await _authRepository.getSavedToken();
      if (token == null || token.isEmpty) {
        safeEmit(ProfileFailure('لا يوجد رمز مصادقة'));
        return;
      }

      final result = await _profileRepository.updateProfileWithPhoto(
        token: token,
        fullName: fullName,
        gender: gender,
        lang: lang,
        personalPhoto: personalPhoto,
        extraPhones: extraPhones, // 👈 new
      );

      _currentProfile = result.user;
      await fetchProfile();
      safeEmit(ProfileUpdateSuccess(message: result.message));
    } on DioException catch (e) {
      dLog('ProfileCubit updateProfileWithPhoto DioException: $e');
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    } catch (e, stackTrace) {
      dLog('ProfileCubit updateProfileWithPhoto error: $e\n$stackTrace');
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  /// Sends verification OTP for a contact being added for the first time.
  /// Uses /auth/request-verification (no old contact to confirm ownership of).
  Future<void> addContactInfo({
    required String type,
    required String value,
  }) async {
    safeEmit(ProfileLoading());
    try {
      await _authRepository.requestVerification(
        phone: type == 'phone' ? value : null,
        email: type == 'email' ? value : null,
      );
      safeEmit(type == 'email'
          ? ProfileChangeEmailSuccess(message: '')
          : ProfileChangePhoneSuccess(message: ''));
    } on DioException catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  /// Verifies a newly added contact using /auth/verify-account.
  /// Used when the user is adding a contact for the first time (no old code).
  Future<void> verifyNewContact({
    String? phone,
    String? email,
    required String code,
  }) async {
    safeEmit(ProfileLoading());
    try {
      final result = await _authRepository.verifyAccount(
        phone: phone,
        email: email,
        code: code,
      );
      await fetchProfile();
      safeEmit(ProfileOtpConfirmSuccess(message: result.message));
    } on DioException catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  /// POST /profile/change-phone — requests OTP to verify the new phone number.
  /// Emits [ProfilePhoneOtpSent] on success so the caller can navigate to the
  /// OTP screen (same flow as auth registration).
  Future<void> changePhone({required String phone}) async {
    safeEmit(ProfileLoading());
    try {
      final token = await _authRepository.getSavedToken();
      if (token == null || token.isEmpty) {
        safeEmit(ProfileFailure('لا يوجد رمز مصادقة'));
        return;
      }
      final result = await _profileRepository.changePhone(
        token: token,
        phone: phone,
      );
      safeEmit(ProfilePhoneOtpSent(
        destination: phone,
        message: result['message'] as String? ?? '',
      ));
    } on DioException catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  /// POST /profile/confirm-otp — confirms the OTP sent by [changePhone].
  Future<void> confirmPhoneOtp({required String code}) async {
    safeEmit(ProfileLoading());
    try {
      final token = await _authRepository.getSavedToken();
      if (token == null || token.isEmpty) {
        safeEmit(ProfileFailure('لا يوجد رمز مصادقة'));
        return;
      }
      final result = await _profileRepository.confirmOtp(
        token: token,
        code: code,
      );
      await fetchProfile();
      safeEmit(ProfileOtpConfirmSuccess(message: result['message'] as String? ?? ''));
    } on DioException catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  /// Sends OTP to both old and new contact values.
  /// [type] is "phone" or "email".
  Future<void> changeContactInfo({
    required String type,
    required String newValue,
  }) async {
    safeEmit(ProfileLoading());
    try {
      final token = await _authRepository.getSavedToken();
      if (token == null || token.isEmpty) {
        safeEmit(ProfileFailure('لا يوجد رمز مصادقة'));
        return;
      }
      final result = await _profileRepository.changeContactInfo(
        token: token,
        type: type,
        newValue: newValue,
      );
      safeEmit(type == 'email'
          ? ProfileChangeEmailSuccess(message: result['message'] as String? ?? '')
          : ProfileChangePhoneSuccess(message: result['message'] as String? ?? ''));
    } on DioException catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  Future<void> verifyContactChange({
    required String oldCode,
    required String newCode,
  }) async {
    safeEmit(ProfileLoading());
    try {
      final token = await _authRepository.getSavedToken();
      if (token == null || token.isEmpty) {
        safeEmit(ProfileFailure('لا يوجد رمز مصادقة'));
        return;
      }
      final result = await _profileRepository.verifyContactChange(
        token: token,
        oldCode: oldCode,
        newCode: newCode,
      );
      await fetchProfile();
      safeEmit(ProfileOtpConfirmSuccess(
        message: result['message'] as String? ?? '',
      ));
    } on DioException catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    }
  }


  Future<void> linkWithGoogle() async {
    safeEmit(ProfileLoading());
    try {
      final token = await _authRepository.getSavedToken();
      if (token == null || token.isEmpty) {
        safeEmit(ProfileFailure('لا يوجد رمز مصادقة'));
        return;
      }
      final idToken = await SocialAuthService.signInWithGoogle();
      if (idToken == null) {
        safeEmit(ProfileFailure('تم إلغاء تسجيل الدخول بواسطة Google'));
        return;
      }
      await _authRepository.linkGoogle(token: token, idToken: idToken);
      await fetchProfile();
      safeEmit(ProfileLinkSuccess(message: 'تم ربط حساب Google بنجاح'));
    } on DioException catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  Future<void> linkWithApple() async {
    safeEmit(ProfileLoading());
    try {
      final token = await _authRepository.getSavedToken();
      if (token == null || token.isEmpty) {
        safeEmit(ProfileFailure('لا يوجد رمز مصادقة'));
        return;
      }
      final appleData = await SocialAuthService.signInWithApple();
      if (appleData == null) {
        safeEmit(ProfileFailure('تم إلغاء تسجيل الدخول بواسطة Apple'));
        return;
      }
      await _authRepository.linkApple(
        token: token,
        idToken: appleData['token']!,
        nonce: appleData['nonce']!,
      );
      await fetchProfile();
      safeEmit(ProfileLinkSuccess(message: 'تم ربط حساب Apple بنجاح'));
    } on DioException catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      safeEmit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  void reset() {
    _currentProfile = null;
    safeEmit(ProfileInitial());
  }
}