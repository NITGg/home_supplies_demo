import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:tawreedat_courier/core/utils/secure_storage_service.dart';

class BiometricManager {
  static final BiometricManager _instance = BiometricManager._internal();

  factory BiometricManager() => _instance;

  BiometricManager._internal();

  final BiometricAuthService _biometricService = BiometricAuthService();

  Future<bool> verifyBiometric({required BuildContext context}) async {
    try {
      final token = await SecureStorageService().getToken();
      if (token == null || token.isEmpty) {
        log('BiometricManager: No token found, skipping biometric check');
        return true; // no auth needed
      }

      final isAvailable = await _biometricService.shouldShowBiometric();
      if (!isAvailable) {
        log('BiometricManager: Biometric not available, allowing access');
        return true; // no biometrics configured
      }

      log('BiometricManager: Starting biometric authentication');
      final result = await _biometricService.authenticateForLogin(
        reason: 'Authenticate to continue',
      );

      if (result == BiometricAuthResult.success) {
        log('BiometricManager: Biometric authentication successful');
        return true;
      }

      // Show error message if failed
      if (result == BiometricAuthResult.failed && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed')),
        );
      }

      log('BiometricManager: Biometric authentication failed with result: $result');
      return false;
    } catch (e) {
      log('BiometricManager: Error during verification: $e');
      // On error, allow access to prevent lockout
      return true;
    }
  }
}

class BiometricAuthService {
  static final BiometricAuthService _instance =
  BiometricAuthService._internal();

  factory BiometricAuthService() => _instance;

  BiometricAuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics =
      await _localAuth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      log('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types (fingerprint, face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      log('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticate using biometrics
  /// Returns true if authentication succeeds
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
    String? androidTitle,
    String? androidSubtitle,
    String? androidCancelButton,
    String? iosLocalizedFallbackTitle,
  }) async {
    try {
      // Check if biometrics are available
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return BiometricAuthResult.notAvailable;
      }

      // Check if there are enrolled biometrics
      final List<BiometricType> availableBiometrics =
      await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        return BiometricAuthResult.notEnrolled;
      }

      // Perform authentication
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        authMessages: [
          AndroidAuthMessages(
            signInTitle: 'تأكيد الهوية | Verify Identity',
            cancelButton: 'إلغاء | Cancel',
            signInHint: 'استخدم البصمة أو الوجه | Use fingerprint or face',
          ),
        ],
        biometricOnly: true,

      );

      if (didAuthenticate) {
        return BiometricAuthResult.success;
      } else {
        return BiometricAuthResult.failed;
      }
    } on PlatformException catch (e) {
      log('Biometric authentication error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'NotAvailable':
          return BiometricAuthResult.notAvailable;
        case 'NotEnrolled':
        case 'PasscodeNotSet':
          return BiometricAuthResult.notEnrolled;
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return BiometricAuthResult.lockedOut;
        case 'biometric_error':
          return BiometricAuthResult.error;
        default:
          return BiometricAuthResult.failed;
      }
    } catch (e) {
      log('Unexpected biometric error: $e');
      return BiometricAuthResult.error;
    }
  }

  /// Authenticate for login - convenience method
  Future<BiometricAuthResult> authenticateForLogin({
    required String reason,
    String? androidTitle,
  }) async {
    return await authenticate(
      localizedReason: reason,
      androidTitle: androidTitle ?? 'Login',
      androidSubtitle: 'Authenticate to access your account',
      androidCancelButton: 'Cancel',
    );
  }

  /// Check if biometric should be shown (enabled and available)
  Future<bool> shouldShowBiometric() async {
    final bool enabled = true;
    final bool available = await isBiometricAvailable();
    final biometrics = await getAvailableBiometrics();
    return enabled && available && biometrics.isNotEmpty;
  }

  /// Get biometric type as string for display
  Future<String> getBiometricTypeString() async {
    final List<BiometricType> availableBiometrics =
    await getAvailableBiometrics();

    if (availableBiometrics.isEmpty) {
      return 'Biometric';
    }

    if (availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (availableBiometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (availableBiometrics.contains(BiometricType.strong)) {
      return 'Biometric';
    } else {
      return 'Biometric';
    }
  }
}

/// Enum for biometric authentication results
enum BiometricAuthResult {
  success,
  failed,
  notAvailable,
  notEnrolled,
  lockedOut,
  canceled,
  error,
}