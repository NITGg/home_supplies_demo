import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
  SecureStorageService._internal();

  factory SecureStorageService() => _instance;

  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Keys
  static const String _accessTokenKey     = 'access_token';
  static const String _refreshTokenKey    = 'refresh_token';
  static const String _userProfileKey     = 'user_profile';
  static const String _localeKey          = 'app_locale';
  static const String _sessionStartKey    = 'session_start_ms';
  static const String _linkAccountShownKey = 'link_account_shown';
  static const String _availabilityKey    = 'courier_availability';
  static const String _deliveryAreasShownKey = 'delivery_areas_shown';
  static const String _hiddenOrderIdsKey     = 'hidden_order_ids';

  // ─── Self-healing wrappers ────────────────────────────────────────────────

  Future<T?> _guardedRead<T>(Future<T?> Function() action) async {
    try {
      return await action();
    } catch (e) {
      final error = e.toString().toLowerCase();

      final isCryptoError =
          error.contains('keystore') ||
              error.contains('key permanently invalidated') ||
              error.contains('failed to unwrap key') ||
              error.contains('badpaddingexception') ||
              error.contains('invalidkeyexception') ||
              error.contains('decrypt') ||
              error.contains('encrypt');

      if (isCryptoError) {
        try {
          await _storage.deleteAll();
        } catch (_) {}
      }

      return null;
    }
  }

  Future<void> _guardedWrite(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      final error = e.toString().toLowerCase();

      final isCryptoError =
          error.contains('keystore') ||
              error.contains('key permanently invalidated') ||
              error.contains('failed to unwrap key') ||
              error.contains('badpaddingexception') ||
              error.contains('invalidkeyexception');

      if (isCryptoError) {
        try {
          await _storage.deleteAll();
        } catch (_) {}
      }
    }
  }

  // ─── Locale ───────────────────────────────────────────────────────────────

  Future<void> saveLocale(String languageCode) async {
    await _guardedWrite(() async {
      await _storage.write(key: _localeKey, value: languageCode);
    });
  }

  Future<String?> getLocale() async {
    return await _guardedRead(() async {
      return await _storage.read(key: _localeKey);
    });
  }

  Future<void> deleteLocale() async {
    await _storage.delete(key: _localeKey);
  }

  // ─── Session lifetime (SEC-07) ────────────────────────────────────────────

  /// Records the time the session was first created. Called automatically by
  /// [saveToken] on first save; subsequent token refreshes do not reset it.
  Future<void> _initSessionStart() async {
    final existing = await _guardedRead(() async {
      return await _storage.read(key: _sessionStartKey);
    });

    if (existing == null) {
      await _guardedWrite(() async {
        await _storage.write(
          key: _sessionStartKey,
          value: DateTime.now().millisecondsSinceEpoch.toString(),
        );
      });
    }
  }

  Future<DateTime?> getSessionStart() async {
    final val = await _guardedRead(() async {
      return await _storage.read(key: _sessionStartKey);
    });

    if (val == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(val));
  }

  Future<void> deleteSessionStart() async {
    await _storage.delete(key: _sessionStartKey);
  }

  // ─── Access token ─────────────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    await _guardedWrite(() async {
      await _storage.write(key: _accessTokenKey, value: token);
    });
    await _initSessionStart();
  }

  Future<String?> getToken() async {
    return await _guardedRead(() async {
      return await _storage.read(key: _accessTokenKey);
    });
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  // ─── Refresh token ────────────────────────────────────────────────────────

  Future<void> saveRefreshToken(String token) async {
    await _guardedWrite(() async {
      await _storage.write(key: _refreshTokenKey, value: token);
    });
  }

  Future<String?> getRefreshToken() async {
    return await _guardedRead(() async {
      return await _storage.read(key: _refreshTokenKey);
    });
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  // ─── User profile ─────────────────────────────────────────────────────────

  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final jsonString = jsonEncode(profile);
    await _guardedWrite(() async {
      await _storage.write(key: _userProfileKey, value: jsonString);
    });
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final jsonString = await _guardedRead(() async {
      return await _storage.read(key: _userProfileKey);
    });

    if (jsonString != null) {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> deleteUserProfile() async {
    await _storage.delete(key: _userProfileKey);
  }

  // ─── Clear all ────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    final areasAlreadyShown = await hasDeliveryAreasBeenShown();
    await _storage.deleteAll();
    await setOnboardingShown();
    if (areasAlreadyShown) await setDeliveryAreasShown();
  }

  // ─── Onboarding ───────────────────────────────────────────────────────────

  Future<void> setOnboardingShown() async {
    await _guardedWrite(() async {
      await _storage.write(key: 'onboarding_shown', value: 'shown');
    });
  }

  Future<String?> getOnboardingStatus() async {
    return await _guardedRead(() async {
      return await _storage.read(key: 'onboarding_shown');
    });
  }

  Future<bool> shouldShowOnboarding() async {
    final status = await getOnboardingStatus();
    return status != 'shown';
  }

  // ─── Link-account sheet (show once, ever) ────────────────────────────────

  /// Call this right after the sheet is shown so it never appears again.
  Future<void> setLinkAccountShown() async {
    await _guardedWrite(() async {
      await _storage.write(key: _linkAccountShownKey, value: 'shown');
    });
  }

  /// Returns true only the very first time (key absent → false).
  Future<bool> hasLinkAccountBeenShown() async {
    final val = await _guardedRead(() async {
      return await _storage.read(key: _linkAccountShownKey);
    });
    return val == 'shown';
  }

  // ─── Availability ─────────────────────────────────────────────────────────

  Future<void> saveAvailability(bool isAvailable) async {
    await _guardedWrite(() async {
      await _storage.write(key: _availabilityKey, value: isAvailable.toString());
    });
  }

  /// Defaults to true (available) if never set.
  Future<bool> getAvailability() async {
    final val = await _guardedRead(() async {
      return await _storage.read(key: _availabilityKey);
    });
    return val == null ? true : val == 'true';
  }

  // ─── Delivery-areas sheet (show once, ever) ───────────────────────────────

  Future<void> setDeliveryAreasShown() async {
    await _guardedWrite(() async {
      await _storage.write(key: _deliveryAreasShownKey, value: 'shown');
    });
  }

  Future<bool> hasDeliveryAreasBeenShown() async {
    final val = await _guardedRead(() async {
      return await _storage.read(key: _deliveryAreasShownKey);
    });
    return val == 'shown';
  }

  // ─── Hidden order IDs (client-side soft-delete) ───────────────────────────

  Future<Set<int>> getHiddenOrderIds() async {
    final val = await _guardedRead(() async {
      return await _storage.read(key: _hiddenOrderIdsKey);
    });
    if (val == null || val.isEmpty) return {};
    return val.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toSet();
  }

  Future<void> addHiddenOrderId(int id) async {
    final ids = await getHiddenOrderIds();
    ids.add(id);
    await _guardedWrite(() async {
      await _storage.write(key: _hiddenOrderIdsKey, value: ids.join(','));
    });
  }

  Future<void> removeHiddenOrderId(int id) async {
    final ids = await getHiddenOrderIds();
    ids.remove(id);
    await _guardedWrite(() async {
      await _storage.write(key: _hiddenOrderIdsKey, value: ids.join(','));
    });
  }
}