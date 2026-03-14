import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/utils/api_client.dart';
import 'package:tawreedat_go/core/utils/secure_storage_service.dart';
import 'package:tawreedat_go/features/auth/data/repositories/auth_repository.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/social_auth_service.dart';
import 'auth_state.dart';

// Global variables for token and user ID
String kAuthtoken = '';
String kUserId = '';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit(this._repository) : super(AuthInitial());

  // ✅ Register FCM token with backend after successful auth
  Future<void> _registerFCMToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && kAuthtoken.isNotEmpty) {
        await ApiClient.instance.dio.post(
          '/profile/fcm-token',
          data: {'fcmToken': fcmToken},
          options: Options(
            headers: {
              'Authorization':
                  'Bearer ${await SecureStorageService().getToken()}',
            },
          ),
        );
        log('✅ FCM token registered successfully');
      }
    } catch (e) {
      log('⚠️ Error registering FCM token: $e');
      // Non-critical — don't throw
    }
  }

  // Helper function to initialize user session (token, profile)
  Future<void> _initializeUserSession() async {
    kAuthtoken = await _repository.getSavedToken() ?? '';

    var prof = await SecureStorageService().getUserProfile();
    if (prof != null) {
      kUserId = prof['id']?.toString() ?? '';
    }

    // ✅ Register FCM token after session is initialized (kAuthtoken is set)
    await _registerFCMToken();
  }

  Future<void> register({
    required var context,
    required String fullName,
    required String phone,
    required String password,
    String? email,
  }) async {
    emit(AuthLoading());
    try {
      final result = await _repository.register(
        context: context,
        fullName: fullName,
        phone: phone,
        password: password,
        email: email,
      );

      await _initializeUserSession();

      emit(AuthSuccess(shortAuthResponse: result));
    } catch (e) {
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

      // ✅ Check role before proceeding
      final userRole = result.user.role ?? '';
      if (userRole == 'Courier') {
        emit(AuthRoleNotAllowed('هذا التطبيق مخصص للعميل وليس للمندوب'));
        return;
      }

      await _initializeUserSession();
      emit(AuthSuccess(shortAuthResponse: result));
    } catch (e) {
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
        // ✅ Check role before proceeding
        final userRole = result.user.role ?? '';
        if (userRole == 'Courier') {
          emit(AuthRoleNotAllowed('هذا التطبيق مخصص للعميل وليس للمندوب'));
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

  Future<void> signInWithApple() async {
    emit(AuthLoading());
    try {
      final appleData = await SocialAuthService.signInWithApple();

      if (appleData != null) {
        final token = appleData['token'];
        final fullName = appleData['fullName'];

        if (token == null) {
          emit(AuthFailure('فشل الحصول على بيانات Apple'));
          return;
        }

        final result = await _repository.verifyAppleToken(token, fullName);
        // ✅ Check role before proceeding
        final userRole = result.user.role ?? '';
        if (userRole == 'Courier') {
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
}
