import 'package:flutter/material.dart';

import '../../config/chat_feature_config.dart';

/// Bottom input bar for the chat screen.
///
/// Media action buttons (voice, image, file) are automatically shown/hidden
/// based on [ChatFeatureConfig] flags. When all are disabled only the text
/// field and send button remain visible.
///
/// Pass [isEnabled] = false to lock the entire input (chat closed state).
class ChatInput extends StatefulWidget {
  final bool isEnabled;
  final void Function(String text) onSendText;

  /// Called on every keystroke — used by the cubit to emit typing events.
  final VoidCallback? onTyping;

  // Media callbacks — only invoked when the corresponding feature is ON.
  final VoidCallback? onAttachImage;
  final VoidCallback? onAttachFile;
  final VoidCallback? onRecordVoice;

  const ChatInput({
    super.key,
    required this.onSendText,
    this.isEnabled = true,
    this.onTyping,
    this.onAttachImage,
    this.onAttachFile,
    this.onRecordVoice,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
      if (has) widget.onTyping?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.isEnabled) return;
    widget.onSendText(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewPadding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withOpacity(0.15),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Optional media buttons ───────────────────────────────────────
          if (ChatFeatureConfig.enableImages && widget.isEnabled)
            _MediaButton(
              icon: Icons.image_outlined,
              onTap: widget.onAttachImage,
            ),
          if (ChatFeatureConfig.enableFiles && widget.isEnabled)
            _MediaButton(
              icon: Icons.attach_file_rounded,
              onTap: widget.onAttachFile,
            ),
          if (ChatFeatureConfig.enableVoiceNotes &&
              widget.isEnabled &&
              !_hasText)
            _MediaButton(
              icon: Icons.mic_none_rounded,
              onTap: widget.onRecordVoice,
            ),

          // ── Text field ───────────────────────────────────────────────────
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: widget.isEnabled
                    ? colorScheme.surface
                    : colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.isEnabled,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: widget.isEnabled
                      ? 'Type a message…'
                      : 'This chat is closed',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 15,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // ── Send button ──────────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _hasText && widget.isEnabled
                ? _SendButton(key: const ValueKey('send'), onTap: _send)
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _MediaButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22),
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
      onPressed: onTap,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SendButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}
