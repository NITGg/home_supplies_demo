import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/utils/api_client.dart';
import 'package:tawreedat_go/core/utils/secure_storage_service.dart';
import 'package:tawreedat_go/features/auth/data/repositories/auth_repository.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/social_auth_service.dart';
import 'auth_state.dart';

String kAuthtoken = '';
String kUserId = '';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  // Stored during register() so verifyRegistrationOtp() can resolve the next
  // channel's destination even though the OTP screen only passes one channel.
  String? _registeredPhone;
  String? _registeredEmail;

  AuthCubit(this._repository) : super(AuthInitial());

  void reset() => emit(AuthInitial());

  Future<void> _registerFCMToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final hasSession = await SecureStorageService().getToken() != null;
      if (fcmToken != null && hasSession) {
        // Interceptor injects Authorization header automatically
        await ApiClient.instance.dio.post(
          '/profile/fcm-token',
          data: {'fcmToken': fcmToken},
        );
        dLog('✅ FCM token registered successfully');
      }
    } catch (e) {
      dLog('⚠️ Error registering FCM token: $e');
    }
  }

  Future<void> _initializeUserSession() async {
    dLog('🔑 _initializeUserSession: reading token from storage');
    kAuthtoken = await _repository.getSavedToken() ?? '';
    dLog('🔑 _initializeUserSession: token=${kAuthtoken.isNotEmpty ? '[present]' : '[MISSING]'}');
    var prof = await SecureStorageService().getUserProfile();
    if (prof != null) {
      kUserId = prof['id']?.toString() ?? '';
      dLog('🔑 _initializeUserSession: userId=$kUserId');
    } else {
      dLog('⚠️ _initializeUserSession: no profile in storage');
    }
    await _registerFCMToken();
  }

  Future<void> register({
    required var context,
    required String fullName,
    required String phone,
    required String password,
    String? email,
    String? gender,
  }) async {
    emit(AuthLoading());
    try {
      dLog('📝 register: phone=$phone email=$email');
      final result = await _repository.register(
        context: context,
        fullName: fullName,
        phone: phone,
        password: password,
        email: email,
        gender: gender,
      );
      dLog('✅ register success: via=${result.via} phone=${result.user.phone} email=${result.user.email}');
      // Token is NOT available yet — user must verify OTP first.
      // Store both contacts so verifyRegistrationOtp can resolve the next channel.
      _registeredPhone = result.user.phone ?? phone;
      _registeredEmail = result.user.email ?? email;
      final destination = result.via == 'email'
          ? (_registeredEmail ?? phone)
          : (_registeredPhone ?? phone);
      dLog('📲 emitting AuthOtpRequired: destination=$destination via=${result.via}');
      emit(AuthOtpRequired(destination: destination, via: result.via));
    } catch (e) {
      dLog('❌ register error: $e');
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  /// Called from the OTP screen after registration to verify the code.
  Future<void> verifyRegistrationOtp({
    String? phone,
    String? email,
    required String code,
  }) async {
    emit(AuthLoading());
    dLog('🔐 verifyRegistrationOtp: phone=$phone email=$email code=$code');
    try {
      final result = await _repository.verifyAccount(
        phone: phone,
        email: email,
        code: code,
      );
      dLog('✅ verifyAccount response: fullyVerified=${result.fullyVerified} via=${result.via} unverified=${result.unverified} token=${result.token != null ? '[present]' : '[null]'}');

      // Phone verification is sufficient to start — treat email-only pending as fully verified.
      final emailOnlyPending = !result.fullyVerified &&
          result.unverified.length == 1 &&
          result.unverified.first == 'email';

      if (result.fullyVerified || emailOnlyPending) {
        dLog('🎉 verified — initializing session (emailOnlyPending=$emailOnlyPending)');
        await _initializeUserSession();
        emit(AuthSuccess());
      } else {
        // One channel verified, another non-email channel is still pending.
        final nextChannel = result.unverified.isNotEmpty
            ? result.unverified.first
            : '';
        dLog('⏭️ partial verification — next channel: $nextChannel');
        emit(AuthNextOtpRequired(
          destination: nextChannel == 'email'
              ? (_registeredEmail ?? '')
              : (_registeredPhone ?? ''),
          via: nextChannel,
        ));
      }
    } catch (e) {
      dLog('❌ verifyRegistrationOtp error: $e');
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  /// Resend OTP during registration verification.
  Future<void> resendRegistrationOtp({String? phone, String? email}) async {
    emit(AuthLoading());
    dLog('🔄 resendRegistrationOtp: phone=$phone email=$email');
    try {
      await _repository.requestVerification(phone: phone, email: email);
      dLog('✅ OTP resent');
      emit(AuthOtpResent(message: 'OTP resent successfully'));
    } catch (e) {
      dLog('❌ resendRegistrationOtp error: $e');
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> login({
    required String phone,
    required String password,
    String locale = 'en',
  }) async {
    emit(AuthLoading());
    try {
      final result = await _repository.login(
        phone: phone,
        password: password,
        locale: locale,
      );

      final userRole = result.user.role ?? '';
      // if (userRole == 'Courier' || userRole == 'Admin') {
      //   emit(AuthRoleNotAllowed('هذا التطبيق مخصص للعميل وليس للمندوب'));
      //   SecureStorageService().deleteToken();
      //   return;
      // }

      await _initializeUserSession();
      emit(AuthSuccess(shortAuthResponse: result));
    } catch (e) {
      // 403 means the account exists but a channel is unverified.
      // Only redirect to OTP when unverified channels are explicitly listed.
      // Any other 403 (e.g. frozen account) falls through to AuthFailure.
      if (e is DioException && e.response?.statusCode == 403) {
        final body = e.response?.data;
        if (body is Map) {
          // unverified list is nested under body['data']
          final inner = body['data'];
          final unverified = (inner is Map
              ? (inner['unverified'] as List?)?.cast<String>()
              : (body['unverified'] as List?)?.cast<String>()) ?? [];
          if (unverified.isNotEmpty) {
            final channel = unverified.first;
            dLog('⚠️ login 403 — unverified: $unverified → redirecting to OTP ($channel)');
            emit(AuthOtpRequired(
              destination: channel == 'email' ? '' : phone,
              via: channel,
            ));
            return;
          }
        }
      }
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> deleteProfile() async {
    emit(AuthLoading());
    try {
      final token = await _repository.getSavedToken();
      final response = await _repository.deleteProfile(token ?? '');
      emit(AuthProfileDeleted(response.message));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final idToken = await SocialAuthService.signInWithGoogle();
      if (idToken != null) {
        final result = await _repository.verifyGoogleToken(idToken);
        final userRole = result.user.role ?? '';
        if (userRole == 'Courier' || userRole == 'Admin') {
          emit(AuthRoleNotAllowed('هذا التطبيق مخصص للعميل وليس للمندوب'));
          SecureStorageService().deleteToken();
          return;
        }
        await _initializeUserSession();
        emit(AuthSuccess(longAuthResponse: result));
      } else {
        emit(AuthFailure('Google sign-in was cancelled.'));
      }
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> signInWithApple() async {
    emit(AuthLoading());
    try {
      final appleData = await SocialAuthService.signInWithApple();
      if (appleData != null) {
        final token = appleData['token'];
        final fullName = appleData['fullName'];

        if (token == null) {
          emit(AuthFailure('فشل الحصول على بيانات Apple'));
          SecureStorageService().deleteToken();
          return;
        }

        final result = await _repository.verifyAppleToken(token, fullName);
        final userRole = result.user.role ?? '';
        if (userRole == 'Courier' || userRole == 'Admin') {
          emit(AuthRoleNotAllowed('هذا التطبيق مخصص للعميل وليس للمندوب'));
          return;
        }
        await _initializeUserSession();
        emit(AuthSuccess(longAuthResponse: result));
      } else {
        emit(AuthFailure('تم إلغاء تسجيل الدخول بواسطة Apple'));
      }
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> linkWithGoogle() async {
    emit(AuthLoading());
    try {
      final token = await _repository.getSavedToken();
      if (token == null || token.isEmpty) {
        emit(AuthFailure('لا يوجد رمز مصادقة'));
        return;
      }
      final idToken = await SocialAuthService.signInWithGoogle();
      if (idToken == null) {
        emit(AuthFailure('تم إلغاء تسجيل الدخول بواسطة Google'));
        return;
      }
      await _repository.linkGoogle(token: token, idToken: idToken);
      emit(AuthSocialLinkSuccess(message: 'تم ربط حساب Google بنجاح'));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> linkWithApple() async {
    emit(AuthLoading());
    try {
      final token = await _repository.getSavedToken();
      if (token == null || token.isEmpty) {
        emit(AuthFailure('لا يوجد رمز مصادقة'));
        return;
      }
      final appleData = await SocialAuthService.signInWithApple();
      if (appleData == null) {
        emit(AuthFailure('تم إلغاء تسجيل الدخول بواسطة Apple'));
        return;
      }
      await _repository.linkApple(
        token: token,
        idToken: appleData['token']!,
        nonce: appleData['nonce']!,
      );
      emit(AuthSocialLinkSuccess(message: 'تم ربط حساب Apple بنجاح'));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> updateProfile({
    String? fullName,
    String? gender,
    String? lang,
    File? personalPhoto,
  }) async {
    emit(AuthLoading());
    try {
      final token = await _repository.getSavedToken();
      final result = await _repository.updateProfile(
        token: token ?? '',
        fullName: fullName,
        gender: gender,
        lang: lang,
        personalPhoto: personalPhoto,
      );
      emit(AuthUpdateSuccess(updatedUser: result.user));
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
      emit(AuthUpdateSuccess());
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> forgotPassword({String? phone, String? email}) async {
    emit(AuthLoading());
    try {
      final via = await _repository.forgotPassword(phone: phone, email: email);
      emit(AuthForgotPasswordOtpSent(
        destination: phone ?? email ?? '',
        message: 'OTP sent successfully',
        via: via,
      ));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
  }) async {
    emit(AuthLoading());
    try {
      await _repository.resetPassword(
        identifier: identifier,
        code: code,
        password: password,
      );
      emit(AuthUpdateSuccess());
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  Future<void> logout() async {
    emit(AuthLoading());
    try {
      await _repository.logout();
      emit(AuthLoggedOut());
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }

  /// Resend OTP — delegates to requestVerification (new endpoint).
  Future<void> resendPhoneOtp({required String phone}) async {
    emit(AuthLoading());
    try {
      await _repository.requestVerification(phone: phone);
      emit(AuthOtpResent(message: 'OTP resent successfully'));
    } catch (e) {
      emit(AuthFailure(extractErrorMessage(e)));
    }
  }
}