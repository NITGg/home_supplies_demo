
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/secure_storage_service.dart';
import '../../core/utils/logger.dart';

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

  static Future<String?> captureOnFirstLaunch({
    required String userId,
  }) async {
    final storage = SecureStorageService();

    final alreadyChecked = await storage.readValue(_checkedKey);
    if (alreadyChecked != null) {
      dLog('ReferralCapture: already checked, skipping');
      return null;
    }

    await storage.writeValue(_checkedKey, 'true');

    try {
      String? code;

      if (Platform.isAndroid) {
        final referrerDetails = await PlayInstallReferrer.installReferrer;
        final referrerString = referrerDetails.installReferrer;

        dLog('ReferralCapture: raw referrer = $referrerString');

        if (referrerString != null &&
            referrerString.isNotEmpty &&
            !_ignoredReferrers.contains(
              referrerString.toLowerCase().trim(),
            )) {
          code = _parseCode(referrerString);
        }
      }

      // iOS clipboard fallback
      if (Platform.isIOS && code == null) {
        final clipboardData = await Clipboard.getData('text/plain');
        final clipboardText = clipboardData?.text?.trim();
        dLog('ReferralCapture: clipboard text = $clipboardText');
        if (clipboardText != null && clipboardText.isNotEmpty) {
          if (clipboardText.contains('ref_code')) {
            // HTML page copies "ref_code%3{code}" where %3 is a broken literal
            // We extract everything after "ref_code%3" directly
            final prefix = 'ref_code%3';
            if (clipboardText.startsWith(prefix)) {
              code = clipboardText.substring(prefix.length).trim();
            } else {
              // Fallback: normalize any variation of %3 / %3D / = and parse
              final normalized = clipboardText
                  .replaceAll(RegExp(r'ref_code%3[Dd]?'), 'ref_code=');
              code = _parseCode(normalized);
            }
          } else {
            // Plain code copied directly
            code = clipboardText;
          }
        }
      }

      dLog('ReferralCapture: parsed code = $code');

      if (code != null && code.isNotEmpty) {
        await _sendCodeToBackend(
          userId: userId,
          code: code,
        );

        // Optional: clear clipboard after consuming
        if (Platform.isIOS) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      }

      return code;
    } on PlatformException catch (e) {
      dLog('ReferralCapture: PlatformException: ${e.message}');
      return null;
    } catch (e) {
      dLog('ReferralCapture: error: $e');
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
      dLog('ReferralCapture: code "$code" saved to backend successfully');
    } on DioException catch (e) {
      dLog('ReferralCapture: failed to save code to backend: ${e.message}');
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