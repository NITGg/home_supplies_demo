import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:tawreedat_courier/core/utils/logger.dart';
import 'package:tawreedat_courier/core/utils/secure_storage_service.dart';
import 'package:tawreedat_courier/core/widgets/banners.dart';

enum BiometricVerifyResult { passed, canceled, failed }

enum BiometricAuthResult {
  success,
  failed,
  notAvailable,
  notEnrolled,
  lockedOut,
  canceled,
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// BiometricManager  (high-level, context-aware)
// ─────────────────────────────────────────────────────────────────────────────

class BiometricManager {
  static final BiometricManager _instance = BiometricManager._internal();
  factory BiometricManager() => _instance;
  BiometricManager._internal();

  final BiometricAuthService _biometricService = BiometricAuthService();

  Future<BiometricVerifyResult> verifyBiometric({
    required BuildContext context,
  }) async {
    try {
      final token = await SecureStorageService().getToken();
      if (token == null || token.isEmpty) {
        dLog('BiometricManager: No token — skipping');
        return BiometricVerifyResult.passed;
      }

      final isAvailable = await _biometricService.shouldShowBiometric();
      if (!isAvailable) {
        dLog('BiometricManager: Not available — skipping');
        return BiometricVerifyResult.passed;
      }

      final result = await _biometricService.authenticateForLogin(
        reason: 'Authenticate to continue',
      );

      switch (result) {
        case BiometricAuthResult.success:
          dLog('BiometricManager: Success');
          return BiometricVerifyResult.passed;

        case BiometricAuthResult.notAvailable:
        case BiometricAuthResult.notEnrolled:
          dLog('BiometricManager: Not set up — allowing');
          return BiometricVerifyResult.passed;

        case BiometricAuthResult.lockedOut:
          dLog('BiometricManager: Locked out — allowing');
          if (context.mounted) showInfoBanner(context, 'Biometric locked out');
          return BiometricVerifyResult.passed;

        case BiometricAuthResult.error:
        // Don't silently allow on unknown errors — keep the lock screen up.
          dLog('BiometricManager: Hardware error — blocking');
          return BiometricVerifyResult.failed;

        case BiometricAuthResult.canceled:
          dLog('BiometricManager: Canceled');
          return BiometricVerifyResult.canceled;

        case BiometricAuthResult.failed:
          dLog('BiometricManager: Failed');
          if (context.mounted) showInfoBanner(context, 'Authentication failed');
          return BiometricVerifyResult.failed;
      }
    } on PlatformException catch (e) {
      dLog('BiometricManager: PlatformException ${e.code} — ${e.message}');
      // PlatformExceptions from the outer layer are unexpected; block.
      return BiometricVerifyResult.failed;
    } catch (e) {
      dLog('BiometricManager: Unexpected error — $e');
      return BiometricVerifyResult.failed;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BiometricAuthService  (low-level, no context)
// ─────────────────────────────────────────────────────────────────────────────

class BiometricAuthService {
  static final BiometricAuthService _instance =
  BiometricAuthService._internal();
  factory BiometricAuthService() => _instance;
  BiometricAuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics || isSupported;
    } on PlatformException catch (e) {
      dLog('Error checking biometric availability: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      dLog('Error getting available biometrics: $e');
      return [];
    }
  }

  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
    String? androidTitle,
    String? androidSubtitle,
    String? androidCancelButton,
  }) async {
    try {
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) return BiometricAuthResult.notAvailable;

      final List<BiometricType> availableBiometrics =
      await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return BiometricAuthResult.notEnrolled;

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        authMessages: [
          AndroidAuthMessages(
            signInTitle: 'تأكيد الهوية | Verify Identity',
            cancelButton: 'إلغاء | Cancel',
            signInHint: 'استخدم البصمة أو الوجه | Use fingerprint or face',
          ),
        ],
        biometricOnly: false,
      );

      return didAuthenticate
          ? BiometricAuthResult.success
          : BiometricAuthResult.failed;

    } on PlatformException catch (e) {
      dLog('Biometric PlatformException: ${e.code} — ${e.message}');
      return _mapErrorCode(e.code);
    } catch (e) {
      // local_auth throws LocalAuthException which does NOT extend
      // PlatformException, so cancel/lockout signals land here.
      dLog('Biometric catch: ${e.runtimeType} — $e');
      return _mapErrorString(e.toString());
    }
  }

  /// Maps a known PlatformException error code to a result.
  BiometricAuthResult _mapErrorCode(String code) {
    switch (code) {
    // notAvailable
      case 'NotAvailable':
      case 'no_fragment_activity':
        return BiometricAuthResult.notAvailable;

    // notEnrolled
      case 'NotEnrolled':
      case 'PasscodeNotSet':
      case 'no_biometrics':
        return BiometricAuthResult.notEnrolled;

    // lockedOut
      case 'LockedOut':
      case 'PermanentlyLockedOut':
      case 'locked_out':
      case 'permanently_locked_out':
        return BiometricAuthResult.lockedOut;

    // canceled by user
      case 'UserCanceled':
      case 'user_canceled':
      case 'userCanceled':
      case 'canceled':
        return BiometricAuthResult.canceled;

      default:
        return BiometricAuthResult.error;
    }
  }

  /// Fallback: parse the exception's toString() for LocalAuthException codes.
  BiometricAuthResult _mapErrorString(String raw) {
    final s = raw.toLowerCase();

    if (s.contains('usercanceled') ||
        s.contains('user_canceled') ||
        s.contains('canceled')) {
      return BiometricAuthResult.canceled;
    }
    if (s.contains('lockedout') || s.contains('locked_out')) {
      return BiometricAuthResult.lockedOut;
    }
    if (s.contains('notenrolled') ||
        s.contains('not_enrolled') ||
        s.contains('passcodenotset')) {
      return BiometricAuthResult.notEnrolled;
    }
    if (s.contains('notavailable') || s.contains('not_available')) {
      return BiometricAuthResult.notAvailable;
    }

    return BiometricAuthResult.error;
  }

  Future<BiometricAuthResult> authenticateForLogin({
    required String reason,
    String? androidTitle,
  }) =>
      authenticate(
        localizedReason: reason,
        androidTitle: androidTitle ?? 'Login',
        androidSubtitle: 'Authenticate to access your account',
        androidCancelButton: 'Cancel',
      );

  Future<bool> shouldShowBiometric() async {
    if (!await isBiometricAvailable()) return false;
    final biometrics = await getAvailableBiometrics();
    return biometrics.isNotEmpty;
  }

  Future<String> getBiometricTypeString() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.isEmpty) return 'Biometric';
    if (biometrics.contains(BiometricType.face)) return 'Face ID';
    if (biometrics.contains(BiometricType.fingerprint)) return 'Fingerprint';
    if (biometrics.contains(BiometricType.iris)) return 'Iris';
    return 'Biometric';
  }
}