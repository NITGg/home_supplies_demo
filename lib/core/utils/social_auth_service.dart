import 'package:tawreedat_courier/core/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SocialAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static Future<void> initialize({
    String? clientId,
    String? serverClientId,
  }) async {
    await _googleSignIn.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );
  }

  /// Start Google sign-in and return a map with:
  ///   'token'    – idToken (sent to backend)
  ///   'fullName' – display name (may be null)
  ///   'photoUrl' – profile picture URL (may be null)
  ///
  /// Returns null if the user cancelled or the flow failed.
  static Future<Map<String, String?>?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.authenticate();
      final auth = account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        if (kDebugMode) print('❌ Google Sign-In: idToken is null');
        return null;
      }

      return {
        'token': idToken,
        'fullName': account.displayName,
        'photoUrl': account.photoUrl,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Google Sign-In failed: $e');
      return null;
    }
  }

  /// Start Apple sign-in and return a map with:
  ///   'token'    – identityToken (sent to backend)
  ///   'fullName' – constructed from given + family name (may be empty)
  ///
  /// Returns null if the user cancelled or the flow failed.
  static Future<Map<String, String?>?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null) {
        if (kDebugMode) print('❌ Apple Sign-In: identityToken is null');
        return null;
      }

      final fullName = _constructFullName(
        credential.givenName,
        credential.familyName,
      );

      if (kDebugMode) {
        print('✅ Apple Full Name: $fullName');
        print('✅ Apple Email: ${credential.email ?? "Not provided"}');
      }

      return {
        'token': identityToken,
        'fullName': fullName.isNotEmpty ? fullName : null,
      };
    } catch (e) {
      dLog('❌ Apple Sign-In failed: $e');
      return null;
    }
  }

  static String _constructFullName(String? givenName, String? familyName) {
    final first = givenName?.trim() ?? '';
    final last = familyName?.trim() ?? '';
    if (first.isEmpty && last.isEmpty) return '';
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$first $last';
  }

  static Future<void> signOut() async {
    await _googleSignIn.disconnect();
  }
}