/// Carries social-auth data from the login attempt to the registration screen
/// when the backend responds with 401 (account not found → needs registration).
class SocialRegistrationData {
  final String idToken;
  final String provider; // 'google' | 'apple'
  final String? fullName;

  /// Public profile photo URL (Google only; null for Apple).
  final String? photoUrl;

  const SocialRegistrationData({
    required this.idToken,
    required this.provider,
    this.fullName,
    this.photoUrl,
  });

  bool get isGoogle => provider == 'google';
  bool get isApple => provider == 'apple';
}