import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/utils/secure_storage_service.dart';
import 'package:tawreedat_go/features/auth/data/repositories/auth_repository.dart';

import '../../../core/utils/social_auth_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit(this._repository) : super(AuthInitial());

  // Helper function to initialize user session (token, profile)
  Future<void> _initializeUserSession() async {
    kAuthtoken = await _repository.getSavedToken() ?? '';

    var prof = await SecureStorageService().getUserProfile();
    if (prof != null) {
      kUserId = prof['id']?.toString() ?? '';
    }
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
      emit(AuthFailure(_extractErrorMessage(e)));
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

      await _initializeUserSession();

      emit(AuthSuccess(shortAuthResponse: result));
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  Future<void> deleteProfile() async {
    emit(AuthLoading());
    try {
      final token = await _repository.getSavedToken();
      final response = await _repository.deleteProfile(token ?? '');
      emit(AuthProfileDeleted(response.message));
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final idToken = await SocialAuthService.signInWithGoogle();
      if (idToken != null) {
        final result = await _repository.verifyGoogleToken(idToken);

        await _initializeUserSession();

        emit(AuthSuccess(longAuthResponse: result));
      } else {
        emit(AuthFailure('Google sign-in was cancelled.'));
      }
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
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
      emit(AuthFailure(_extractErrorMessage(e)));
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
      emit(AuthFailure(_extractErrorMessage(e)));
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

        await _initializeUserSession();

        emit(AuthSuccess(longAuthResponse: result));
      } else {
        emit(AuthFailure('تم إلغاء تسجيل الدخول بواسطة Apple'));
      }
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  // Helper function to extract error messages
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
}

// Global variables for token and user ID
late String kAuthtoken;
late String kUserId;