import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/secure_storage_service.dart';
import '../../../core/utils/social_auth_service.dart';
import '../data/models/auth_response_model.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_state.dart';

late String kAuthtoken;
late String kRefreshToken;
late int kUserId;

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit(this._repository) : super(AuthInitial());

  // Store pending data
  String? _pendingPhone;
  String? _pendingForgotPasswordPhone;

  /// GOOGLE SIGN IN - Always requires phone number
  Future<void> signInWithGoogle({required String phone}) async {
    emit(AuthLoading());
    try {
      // Get token from Google
      final idToken = await SocialAuthService.signInWithGoogle();
      if (idToken == null) {
        emit(AuthFailure('Google sign-in was cancelled.'));
        return;
      }

      // Verify with backend (phone is always required)
      final result = await _repository.verifyGoogleToken(
        idToken: idToken,
        phone: phone,
      );

      // Check if phone is verified
      if (!result.data.user.isPhoneVerified) {
        _pendingPhone = phone;
        emit(AuthOtpRequired(
          phone: phone,
          authResponse: result,
        ));
        return;
      }

      await _initializeUserSession(result.data.user);
      emit(AuthSuccess(message: result.message));
    } on DioException catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  /// APPLE SIGN IN - Always requires phone number
  Future<void> signInWithApple({required String phone}) async {
    emit(AuthLoading());
    try {
      // Get token from Apple
      final appleData = await SocialAuthService.signInWithApple();
      if (appleData == null) {
        emit(AuthFailure('تم إلغاء تسجيل الدخول بواسطة Apple'));
        return;
      }

      final token = appleData['token'];
      final fullName = appleData['fullName'];

      if (token == null) {
        emit(AuthFailure('فشل الحصول على بيانات Apple'));
        return;
      }

      // Verify with backend (phone is always required)
      final result = await _repository.verifyAppleToken(
        idToken: token,
        fullName: fullName,
        phone: phone,
      );

      // Check if phone is verified
      if (!result.data.user.isPhoneVerified) {
        _pendingPhone = phone;
        emit(AuthOtpRequired(
          phone: phone,
          authResponse: result,
        ));
        return;
      }

      await _initializeUserSession(result.data.user);
      emit(AuthSuccess(message: result.message));
    } on DioException catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  /// FORGOT PASSWORD - Send OTP
  Future<void> forgotPassword(String phone) async {
    // emit(AuthLoading());

    try {
      final result = await _repository.forgotPassword(phone: phone);

      // Success - OTP sent
      emit(AuthForgotPasswordOtpSent(
        message: result.message,
        phone: phone,
      ));
    } on DioException catch (e) {
      // Handle 400 error - OTP already sent (not expired)
      if (e.response?.statusCode == 400) {
        final message = _extractErrorMessage(e);

        // Check if error is about OTP already being sent
        if (message.toLowerCase().contains('Your OTP not expired yet')){

          log('OTP already sent and not expired, navigating to OTP screen');

          // Treat this as success and navigate to OTP screen
          emit(AuthForgotPasswordOtpSent(
            message: message,
            phone: phone,
          ));
          return;
        }
      }

      // Other errors
      emit(AuthFailure(_extractErrorMessage(e)));
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }


  /// RESET PASSWORD with OTP
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
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  /// REGISTER - Now requires courier info and images
  Future<void> register({
    required BuildContext context,
    required String fullName,
    required String phone,
    required String password,
    required String gender,
    required String vehicleType,
    required String vehiclePlate,
    required File personalPhoto,
    required File nationalIdPhoto,
  }) async {
    emit(AuthLoading());
    try {
      final result = await _repository.register(
        context: context,
        fullName: fullName,
        phone: phone,
        password: password,
        gender: gender,
        vehicleType: vehicleType,
        vehiclePlate: vehiclePlate,
        personalPhoto: personalPhoto,
        nationalIdPhoto: nationalIdPhoto,
      );

      // Store phone for OTP verification
      _pendingPhone = phone;

      // Don't initialize session yet - wait for OTP verification
      emit(AuthOtpRequired(phone: phone, authResponse: result));
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  /// VERIFY PHONE OTP
  Future<void> verifyPhoneOtp({
    required String phone,
    required String userOtp,
  }) async {
    emit(AuthLoading());
    try {
      final result = await _repository.verifyPhoneOtp(
        phone: phone,
        userOtp: userOtp,
      );

      // Get the stored auth data from the previous registration/login
      final token = await _repository.getSavedToken();
      final profile = await SecureStorageService().getUserProfile();

      if (token != null && profile != null) {
        final user = UserModel.fromJson(profile);
        await _initializeUserSession(user);
        emit(AuthSuccess(message: result.message));
      } else {
        emit(AuthFailure('Authentication data not found. Please login again.'));
      }
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  /// RESEND OTP
  Future<void> resendPhoneOtp({required String phone}) async {
    emit(AuthLoading());
    try {
      final result = await _repository.resendPhoneOtp(phone: phone);
      emit(AuthOtpResent(message: result.message));
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  /// LOGIN
  Future<void> login({
    required String phone,
    required String password,
  }) async {
    emit(AuthLoading());
    try {
      final result = await _repository.login(
        phone: phone,
        password: password,
      );

      // Check if phone is verified
      if (!result.data.user.isPhoneVerified) {
        _pendingPhone = phone;
        emit(AuthOtpRequired(phone: phone, authResponse: result));
        return;
      }

      await _initializeUserSession(result.data.user);
      emit(AuthSuccess(message: result.message));
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  /// REFRESH ACCESS TOKEN
  Future<void> refreshAccessToken() async {
    try {
      final newAccessToken = await _repository.refreshAccessToken();
      kAuthtoken = newAccessToken;
      log('Access token refreshed successfully');
    } catch (e) {
      log('Error refreshing access token: $e');
      // If refresh fails, user needs to login again
      emit(AuthFailure('Session expired. Please login again.'));
    }
  }

  /// DELETE PROFILE
  Future<void> deleteProfile() async {
    emit(AuthLoading());
    try {
      final response = await _repository.deleteProfile();
      await _repository.logout();
      emit(AuthProfileDeleted(response));
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  /// UPDATE PROFILE
  Future<void> updateProfile({
    String? fullName,
    String? email,
    String? gender,
    File? imageUrl,
    String? phone,
  }) async {
    emit(AuthLoading());
    try {
      final Map<String, dynamic> data = {};
      if (fullName != null) data['full_name'] = fullName;
      if (gender != null) data['gender'] = gender;
      if (email != null) data['email'] = email;
      if (phone != null) {
        if (!phone.startsWith('+2')) {
          data['phone'] = '+2$phone';
        } else {
          data['phone'] = phone;
        }
      }

      final result = await _repository.updateProfile(
        imageUrl: imageUrl,
        data: data,
      );
      emit(AuthUpdateSuccess(user: result));
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  // Helper function to initialize user session
  Future<void> _initializeUserSession(UserModel user) async {
    kAuthtoken = await _repository.getSavedToken() ?? '';
    kRefreshToken = await _repository.getSavedRefreshToken() ?? '';
    kUserId = user.id;

    var prof = await SecureStorageService().getUserProfile();
    log('User profile loaded: $prof');

    // Optionally register FCM token
    // await _registerFCMToken();
  }

  /// LOGOUT
  Future<void> logout() async {
    try {
      await _repository.logout();
      kAuthtoken = '';
      kRefreshToken = '';
      kUserId = 0;
      emit(AuthLoggedOut());
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
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


  void reset(){
    emit(AuthInitial());
  }
}