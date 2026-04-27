/// Central configuration for the Chat feature.
///
/// Toggle [enableVoiceNotes], [enableImages], or [enableFiles] here to
/// show/hide the corresponding UI controls and upload logic without touching
/// any other file.
class ChatFeatureConfig {
  const ChatFeatureConfig._();

  // ─── Media Feature Toggles ─────────────────────────────────────────────────
  static const bool enableVoiceNotes = false;
  static const bool enableImages = false;
  static const bool enableFiles = false;

  // ─── Pagination ────────────────────────────────────────────────────────────
  /// Number of messages to load per page.
  static const int messagesPageSize = 30;

  // ─── Typing Indicator ──────────────────────────────────────────────────────
  /// How long to wait after the user stops typing before emitting stop_typing.
  static const Duration typingDebounce = Duration(milliseconds: 500);

  /// Auto-hide the "X is typing…" indicator after this duration with no update.
  static const Duration typingIndicatorTimeout = Duration(seconds: 4);

  // ─── UI ────────────────────────────────────────────────────────────────────
  /// Message shown when the chat is closed (order confirmed / completed).
  static const String chatClosedMessage =
      'This chat has been closed as the order is complete.';
}
