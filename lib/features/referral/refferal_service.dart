import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/secure_storage_service.dart';

class ReferralCaptureService {
  static const _checkedKey = 'referral_capture_checked';
  static const _referralParam = 'ref_code';

  static const _ignoredReferrers = {
    'organic',
    'unknown',
    'link2',
    '(not set)',
    'utm_source=google-play&utm_medium=organic',
  };

  static Future<String?> captureOnFirstLaunch({required String userId}) async {
    final storage = SecureStorageService();

    final alreadyChecked = await storage.readValue(_checkedKey);
    if (alreadyChecked != null) {
      log('ReferralCapture: already checked, skipping');
      return null;
    }

    await storage.writeValue(_checkedKey, 'true');

    try {
      final referrerDetails = await PlayInstallReferrer.installReferrer;
      final referrerString = referrerDetails.installReferrer;

      log('ReferralCapture: raw referrer = $referrerString');

      if (referrerString == null ||
          referrerString.isEmpty ||
          _ignoredReferrers.contains(referrerString.toLowerCase().trim())) {
        log('ReferralCapture: ignored referrer value, skipping');
        return null;
      }

      final code = _parseCode(referrerString);
      log('ReferralCapture: parsed code = $code');

      if (code != null) {
        await _sendCodeToBackend(userId: userId, code: code);
      }

      return code;
    } on PlatformException catch (e) {
      log('ReferralCapture: PlatformException (not a Play install): ${e.message}');
      return null;
    } catch (e) {
      log('ReferralCapture: error reading referrer: $e');
      return null;
    }
  }

  static Future<void> _sendCodeToBackend({
    required String userId,
    required String code,
  }) async {
    try {
      await ApiClient.instance.dio.post(
        '/admin/manage-seller/save-referral-code/$userId',
        data: {'referral_code': code},
      );
      log('ReferralCapture: code "$code" saved to backend successfully');
    } on DioException catch (e) {
      log('ReferralCapture: failed to save code to backend: ${e.message}');
    }
  }

  static String? _parseCode(String referrer) {
    final decoded = Uri.decodeComponent(referrer);
    final params = Uri.splitQueryString(decoded);
    final code = params[_referralParam];
    if (code == null || code.trim().isEmpty) return null;
    return code.trim();
  }

  static Future<void> reset() async {
    await SecureStorageService().deleteValue(_checkedKey);
  }
}