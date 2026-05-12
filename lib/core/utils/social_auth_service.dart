import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'logger.dart';

class SocialAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  /// Initialize once before use (in main() or AuthCubit init)
  static Future<void> initialize({
    String? clientId,
    String? serverClientId,
  }) async {
    await _googleSignIn.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );
  }

  /// Start Google sign-in flow and return idToken
  static Future<String?> signInWithGoogle() async {
    try {
      // Start authentication flow once
      final account = await _googleSignIn.authenticate();
      // Get authentication tokens
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (kDebugMode) {
        print('✅ Google ID Token: $idToken');
      }
      return idToken; // Send this to your backend
    } catch (e) {
      if (kDebugMode) {
        print('❌ Google Sign-In failed: $e');
      }
      return null;
    }
  }

  /// Start Apple sign-in flow and return [identityToken, fullName]
  /// Returns a Map with 'token' and 'fullName' keys
  static Future<Map<String, String>?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Construct full name from Apple credential
      final String fullName = _constructFullName(
        appleCredential.givenName,
        appleCredential.familyName,
      );

      final String? identityToken = appleCredential.identityToken;

      if (identityToken == null) {
        if (kDebugMode) {
          print('❌ Apple Sign-In: Identity token is null');
        }
        return null;
      }

      if (kDebugMode) {
        print('✅ Apple Identity Token: $identityToken');
        print('✅ Apple Full Name: $fullName');
        print('✅ Apple Email: ${appleCredential.email ?? "Not provided"}');
      }

      return {
        'token': identityToken,
        'fullName': fullName,
      };
    } catch (e) {
      dLog('❌ Apple Sign-In failed: $e');
      return null;
    }
  }

  /// Helper method to construct full name from given and family names
  static String _constructFullName(String? givenName, String? familyName) {
    final firstName = givenName?.trim() ?? '';
    final lastName = familyName?.trim() ?? '';

    if (firstName.isEmpty && lastName.isEmpty) {
      return ''; // Both names are empty
    } else if (firstName.isEmpty) {
      return lastName; // Only last name available
    } else if (lastName.isEmpty) {
      return firstName; // Only first name available
    } else {
      return '$firstName $lastName'; // Both names available
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.disconnect();
  }
}