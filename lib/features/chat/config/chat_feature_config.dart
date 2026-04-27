/// Central configuration for the Chat feature.
class ChatFeatureConfig {
  const ChatFeatureConfig._();

  // ─── Media Feature Toggles ─────────────────────────────────────────────────
  static const bool enableVoiceNotes = false;
  static const bool enableImages = true;  // ← enabled
  static const bool enableFiles = false;

  // ─── Pagination ────────────────────────────────────────────────────────────
  static const int messagesPageSize = 30;

  // ─── Typing Indicator ──────────────────────────────────────────────────────
  static const Duration typingDebounce = Duration(milliseconds: 500);
  static const Duration typingIndicatorTimeout = Duration(seconds: 4);

  // ─── UI ────────────────────────────────────────────────────────────────────
  static const String chatClosedMessage =
      'This chat has been closed as the order is complete.';
}