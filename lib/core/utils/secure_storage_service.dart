import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  // Token
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'token');
  }

  // User data
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(key: 'user_data', value: jsonEncode(userData));
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final jsonStr = await _storage.read(key: 'user_data');
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  Future<void> deleteUserData() async {
    await _storage.delete(key: 'user_data');
  }

  // Clear everything
  Future<void> clearAll() async {
    final onboardingStatus = await getOnboardingStatus();
    await _storage.deleteAll();
    await clearCart();
    if (onboardingStatus == 'shown') {
      await setOnboardingShown();
    }
  }

  // User Profile
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    await _storage.write(key: 'user_profile', value: jsonEncode(profile));
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final jsonStr = await _storage.read(key: 'user_profile');
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  Future<void> deleteUserProfile() async {
    await _storage.delete(key: 'user_profile');
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

  // Cart
  Future<void> saveCart(List<Map<String, dynamic>> cartItems) async {
    await _storage.write(key: 'cart', value: jsonEncode(cartItems));
  }

  Future<List<Map<String, dynamic>>> getCart() async {
    final jsonStr = await _storage.read(key: 'cart');
    if (jsonStr == null) return [];
    final List decoded = jsonDecode(jsonStr);
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> clearCart() async {
    await _storage.delete(key: 'cart');
  }
}
