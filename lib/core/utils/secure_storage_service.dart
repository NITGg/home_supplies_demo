import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userProfileKey = 'user_profile';

  /// Save access token
  Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  /// Get access token
  Future<String?> getToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  /// Delete access token
  Future<void> deleteToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Delete refresh token
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  /// Save user profile
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final jsonString = jsonEncode(profile);
    await _storage.write(key: _userProfileKey, value: jsonString);
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    final jsonString = await _storage.read(key: _userProfileKey);
    if (jsonString != null) {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    }
    return null;
  }

  /// Delete user profile
  Future<void> deleteUserProfile() async {
    await _storage.delete(key: _userProfileKey);
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Onboarding
  Future<void> setOnboardingShown() async {
    await _storage.write(key: 'onboarding_shown', value: 'shown');
  }

  Future<String?> getOnboardingStatus() async {
    return await _storage.read(key: 'onboarding_shown');
  }

  Future<bool> shouldShowOnboarding() async {
    final status = await getOnboardingStatus();
    return status != 'shown';
  }
}