import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/secure_storage_service.dart';
import '../../../core/utils/social_auth_service.dart';
import '../../../core/utils/socket_service.dart';
import '../../../core/utils/api_client.dart';
import '../data/data_sources/auth_remote_data_source.dart';
import '../data/models/social_registration_data.dart';
import '../data/models/vehicles_model.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_state.dart';

String kAuthtoken = '';
late String kRefreshToken;

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit(this._repository) : super(AuthInitial());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed (e.g. widget disposed mid-request).
  @override
  void emit(AuthState state) {
    if (!isClosed) super.emit(state);
  }

  String? _pendingPhone;
  String? _pendingPassword;
  String? _pendingForgotPasswordPhone;

  // Cached so the list survives state transitions (e.g. AuthLoading wipes UI)
  List<VehicleModel> _availableVehicles = [];

  List<VehicleModel> get availableVehicles => _availableVehicles;

  // ── FCM ──────────────────────────────────────────────────────────────────

  Future<void> _registerFCMToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await ApiClient.instance.dio2.post(
          '/profile/fcm-token',
          data: {'fcmToken': fcmToken},
          options: Options(
            headers: {
              'Authorization':
                  'Bearer ${await SecureStorageService().getToken()}',
            },
          ),
        );
        dLog('✅ FCM token registered successfully');
      } else {
        dLog(
          '⚠️ FCM token registration failed: no token or auth token $kAuthtoken',
        );
      }
    } catch (e) {
      dLog('⚠️ Error registering FCM token: $e');
      // Non-critical — don't throw
    }
  }

  // ── VEHICLES ─────────────────────────────────────────────────────────────

  Future<void> fetchAvailableVehicles() async {
    try {
      final result = await _repository.fetchAvailableVehicles();
      _availableVehicles = result.vehicles;
      emit(AuthVehiclesLoaded(vehicles: result.vehicles));
    } on DioException catch (e) {
      dLog('AuthCubit fetchAvailableVehicles DioException: $e');
      emit(AuthVehiclesFailure(extractErrorMessage(e)));
    } catch (e) {
      dLog('AuthCubit fetchAvailableVehicles error: $e');
      emit(AuthVehiclesFailure(extractErrorMessage(e)));
    }
  }

  // ── SOCIAL AUTH ───────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final googleData = await SocialAuthService.signInWithGoogle();
      if (googleData == null) {
        emit(AuthFailure('Google sign-in was cancelled.'));
        return;
      }

      final idToken = googleData['token']!;

      try {
        final result = await _repository.verifyGoogleToken(idToken: idToken);
        await _registerFCMToken();
        emit(AuthSuccess(message: result.message));
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          emit(
            AuthSocialRegistrationRequired(
              SocialRegistrationData(
                idToken: idToken,
                provider: 'google',
                fullName: googleData['fullName'],
                photoUrl: googleData['photoUrl'],
              ),
            ),
          );
        } else {
          emit(AuthFailure(extractErrorMessage(e)));
        }
      }
    } on DioException catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> signInWithApple() async {
    emit(AuthLoading());
    try {
      final appleData = await SocialAuthService.signInWithApple();
      if (appleData == null) {
        emit(AuthFailure('تم إلغاء تسجيل الدخول بواسطة Apple'));
        return;
      }

      final token = appleData['token'];
      if (token == null) {
        emit(AuthFailure('فشل الحصول على بيانات Apple'));
        return;
      }

      try {
        final result = await _repository.verifyAppleToken(
          idToken: token,
          fullName: appleData['fullName'],
        );
        await _registerFCMToken();
        emit(AuthSuccess(message: result.message));
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          emit(
            AuthSocialRegistrationRequired(
              SocialRegistrationData(
                idToken: token,
                provider: 'apple',
                fullName: appleData['fullName'],
                photoUrl: null,
              ),
            ),
          );
        } else {
          emit(AuthFailure(extractErrorMessage(e)));
        }
      }
    } on DioException catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  // ── SOCIAL REGISTER ───────────────────────────────────────────────────────

  Future<void> googleRegister({
    required BuildContext context,
    required String idToken,
    required String fullName,
    required String phone,
    required String gender,
    required String vehicleId,
    required String nationalId,
    required String vehiclePlate,
    required File? personalPhoto,
    required File nationalIdPhotoFront,
    required File nationalIdPhotoBack,
    File? vehicleLicenseFront,
    File? vehicleLicenseBack,
    File? courierLicenseFront,
    File? courierLicenseBack,
    File? criminalRecord,
  }) async {
    emit(AuthLoading());
    try {
      final result = await _repository.googleRegister(
        idToken: idToken,
        fullName: fullName,
        phone: phone,
        gender: gender,
        vehicleId: vehicleId,
        nationalId: nationalId,
        vehiclePlate: vehiclePlate,
        personalPhoto: personalPhoto,
        nationalIdPhotoFront: nationalIdPhotoFront,
        nationalIdPhotoBack: nationalIdPhotoBack,
        vehicleLicenseFront: vehicleLicenseFront,
        vehicleLicenseBack: vehicleLicenseBack,
        courierLicenseFront: courierLicenseFront,
        courierLicenseBack: courierLicenseBack,
        criminalRecord: criminalRecord,
      );
      await _registerFCMToken();
      emit(AuthSuccess(message: result.message));
    } on ImageValidationException catch (e) {
      emit(AuthFailure(e.message));
    } on DioException catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> appleRegister({
    required BuildContext context,
    required String idToken,
    required String fullName,
    required String phone,
    required String gender,
    required String vehicleId,
    required String nationalId,
    required String vehiclePlate,
    required File? personalPhoto,
    required File nationalIdPhotoFront,
    required File nationalIdPhotoBack,
    File? vehicleLicenseFront,
    File? vehicleLicenseBack,
    File? courierLicenseFront,
    File? courierLicenseBack,
    File? criminalRecord,
  }) async {
    emit(AuthLoading());
    try {
      final result = await _repository.appleRegister(
        idToken: idToken,
        fullName: fullName,
        phone: phone,
        gender: gender,
        vehicleId: vehicleId,
        nationalId: nationalId,
        vehiclePlate: vehiclePlate,
        personalPhoto: personalPhoto,
        nationalIdPhotoFront: nationalIdPhotoFront,
        nationalIdPhotoBack: nationalIdPhotoBack,
        vehicleLicenseFront: vehicleLicenseFront,
        vehicleLicenseBack: vehicleLicenseBack,
        courierLicenseFront: courierLicenseFront,
        courierLicenseBack: courierLicenseBack,
        criminalRecord: criminalRecord,
      );
      await _registerFCMToken();
      emit(AuthSuccess(message: result.message));
    } on ImageValidationException catch (e) {
      emit(AuthFailure(e.message));
    } on DioException catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  // ── LINK SOCIAL ───────────────────────────────────────────────────────────

  Future<void> linkGoogleAccount() async {
    emit(AuthLoading());
    try {
      final auth = await SocialAuthService.signInWithGoogle();
      if (auth == null) {
        emit(AuthFailure('Google sign-in was cancelled.'));
        return;
      }
      final result = await _repository.linkGoogle(idToken: auth['token'] ?? '');
      final message = result['message'] ?? 'Google account linked successfully';
      emit(AuthSocialLinkSuccess(message: message));
    } on DioException catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> linkAppleAccount() async {
    emit(AuthLoading());
    try {
      final appleData = await SocialAuthService.signInWithApple();
      if (appleData == null) {
        emit(AuthFailure('تم إلغاء ربط الحساب بواسطة Apple'));
        return;
      }
      final token = appleData['token'];
      final fullName = appleData['fullName'];
      if (token == null) {
        emit(AuthFailure('فشل الحصول على بيانات Apple'));
        return;
      }
      final result = await _repository.linkApple(
        idToken: token,
        fullName: fullName,
      );
      final message = result['message'] ?? 'Apple account linked successfully';
      emit(AuthSocialLinkSuccess(message: message));
    } on DioException catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  // ── PASSWORD ──────────────────────────────────────────────────────────────

  Future<void> forgotPassword(String phone) async {
    try {
      final result = await _repository.forgotPassword(phone: phone);
      emit(AuthForgotPasswordOtpSent(message: result.message, phone: phone));
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final message = extractErrorMessage(e);
        if (message.toLowerCase().contains('your otp not expired yet')) {
          dLog('OTP already sent and not expired, navigating to OTP screen');
          emit(AuthForgotPasswordOtpSent(message: message, phone: phone));
          return;
        }
      }
      emit(AuthFailure(extractErrorMessage(e)));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> resetPassword({
    required String phone,
    required String userOtp,
    required String newPassword,
  }) async {
    emit(AuthLoading());
    try {
      final result = await _repository.resetPassword(
        phone: phone,
        userOtp: userOtp,
        newPassword: newPassword,
      );
      _pendingForgotPasswordPhone = null;
      emit(AuthPasswordResetSuccess(message: result.message));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> changePassword(
    String oldPassword,
    String newPassword,
    var context,
  ) async {
    emit(AuthLoading());
    try {
      final token = await _repository.getSavedToken();
      await _repository.changePassword(
        context: context,
        token: token ?? '',
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      // SEC-09: always clear local session immediately after password change.
      // Server-side logout is best-effort — local wipe must not depend on it.
      kAuthtoken = '';
      kRefreshToken = '';
      SocketService().stop();
      await SecureStorageService().clearAll();
      _repository.logout().ignore();
      emit(AuthLoggedOut());
    } catch (e) {
      String message = e.toString();
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          message = data['message'];
        }
      }
      emit(AuthFailure(message));
    }
  }

  // ── REGISTER / OTP ────────────────────────────────────────────────────────

  Future<void> register({
    required BuildContext context,
    required String fullName,
    required String phone,
    required String password,
    required String gender,
    required String nationalId,
    required String vehicleId,
    required String vehiclePlate,
    required File? personalPhoto,
    required File nationalIdPhotoFront,
    required File nationalIdPhotoBack,
    File? vehicleLicenseFront,
    File? vehicleLicenseBack,
    File? courierLicenseFront,
    File? courierLicenseBack,
    File? criminalRecord,
  }) async {
    emit(AuthLoading());
    try {
      final result = await _repository.register(
        context: context,
        fullName: fullName,
        phone: phone,
        password: password,
        gender: gender,
        vehicleId: vehicleId,
        vehiclePlate: vehiclePlate,
        nationalId: nationalId,
        personalPhoto: personalPhoto,
        nationalIdPhotoFront: nationalIdPhotoFront,
        nationalIdPhotoBack: nationalIdPhotoBack,
        vehicleLicenseFront: vehicleLicenseFront,
        vehicleLicenseBack: vehicleLicenseBack,
        courierLicenseFront: courierLicenseFront,
        courierLicenseBack: courierLicenseBack,
        criminalRecord: criminalRecord,
      );
      await _registerFCMToken();
      _pendingPhone = phone;
      emit(AuthOtpRequired(phone: phone, authResponse: result));
    } on ImageValidationException catch (e) {
      emit(AuthFailure(e.message));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  // ── OTP VERIFICATION (new unified endpoint) ──────────────────────────────

  /// Verify OTP for registration or login (verify_type: VERIFY).
  Future<void> verifyAccountOtp({
    required String phone,
    required String code,
    String channel = 'phone',
  }) async {
    emit(AuthLoading());
    try {
      final result = await _repository.verifyOtp(
        phone: phone,
        userOtp: code,
        verifyType: 'VERIFY',
      );
      // Re-login to get the session token now that the phone is verified.
      if (_pendingPassword != null) {
        final pendingPwd = _pendingPassword!;
        _pendingPassword = null;
        await _repository.login(phone: phone, password: pendingPwd);
      }
      await _registerFCMToken();
      emit(AuthSuccess(message: result.message));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  /// Resend OTP for registration/login verification.
  /// Does NOT emit AuthLoading — resend is a quiet background action.
  Future<void> resendRegistrationVerification({String? phone, String? email}) async {
    try {
      final result = await _repository.resendOtp(
        phone: phone ?? email ?? '',
        verifyType: 'VERIFY',
      );
      emit(AuthVerificationCodeResent(message: result.message));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  /// Verify OTP and reset password in one call for the forgot-password flow.
  Future<void> verifyForgetPasswordAndReset({
    required String identifier,
    required String code,
    required String password,
  }) async {
    emit(AuthLoading());
    try {
      final result = await _repository.verifyOtp(
        phone: identifier,
        userOtp: code,
        verifyType: 'FORGET_PASSWORD',
        newPassword: password,
      );
      emit(AuthPasswordResetSuccess(message: result.message));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  // ── LOGIN ─────────────────────────────────────────────────────────────────

  Future<void> login({required String phone, required String password}) async {
    emit(AuthLoading());
    try {
      final result = await _repository.login(phone: phone, password: password);
      _pendingPhone = phone;

      if (result.data.verfied == false) {
        emit(AuthOtpRequired(phone: phone, authResponse: result));
      } else {
        await _registerFCMToken();
        emit(AuthSuccess(message: result.message));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _pendingPhone = phone;
        _pendingPassword = password;
        emit(AuthOtpRequired(phone: phone));
      } else {
        emit(AuthFailure(extractErrorMessage(e)));
      }
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  // ── ACCOUNT ───────────────────────────────────────────────────────────────

  Future<void> deleteProfile() async {
    emit(AuthLoading());
    try {
      final response = await _repository.deleteProfile();
      await _repository.logout();
      emit(AuthProfileDeleted(response));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
      kAuthtoken = '';
      kRefreshToken = '';
      SecureStorageService().clearAll();
      emit(AuthLoggedOut());
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  void reset() {
    emit(AuthInitial());
  }
}
