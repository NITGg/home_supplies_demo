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
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userProfileKey = 'user_profile';
  static const String _localeKey = 'app_locale';
  static const String _sessionStartKey = 'session_start_ms';

  // ─────────────────────────────────────────────────────────────
  // Self-healing wrapper
  // ─────────────────────────────────────────────────────────────

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

  /// Save locale
  Future<void> saveLocale(String languageCode) async {
    await _guardedWrite(() async {
      await _storage.write(key: _localeKey, value: languageCode);
    });
  }

  /// Get locale
  Future<String?> getLocale() async {
    return await _guardedRead(() async {
      return await _storage.read(key: _localeKey);
    });
  }

  Future<void> deleteLocale() async {
    await _storage.delete(key: _localeKey);
  }

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

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

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

  Future<void> writeValue(String key, String value) async {
    await _guardedWrite(() async {
      await _storage.write(key: key, value: value);
    });
  }

  Future<String?> readValue(String key) async {
    return await _guardedRead(() async {
      return await _storage.read(key: key);
    });
  }

  Future<void> deleteValue(String key) async {
    await _storage.delete(key: key);
  }

  // ── Hidden order IDs (soft-delete from history) ───────────────────────────

  static const String _hiddenOrderIdsKey = 'hidden_order_ids';

  Future<Set<int>> getHiddenOrderIds() async {
    final raw = await _guardedRead(
      () async => _storage.read(key: _hiddenOrderIdsKey),
    );
    if (raw == null || raw.isEmpty) return {};
    return raw
        .split(',')
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toSet();
  }

  Future<void> addHiddenOrderId(int orderId) async {
    final existing = await getHiddenOrderIds();
    existing.add(orderId);
    await _guardedWrite(() async {
      await _storage.write(
        key: _hiddenOrderIdsKey,
        value: existing.join(','),
      );
    });
  }

  Future<void> removeHiddenOrderId(int orderId) async {
    final existing = await getHiddenOrderIds();
    existing.remove(orderId);
    await _guardedWrite(() async {
      await _storage.write(
        key: _hiddenOrderIdsKey,
        value: existing.join(','),
      );
    });
  }
}