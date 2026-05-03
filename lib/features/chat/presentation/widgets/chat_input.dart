import 'package:flutter/material.dart';

import '../../../../core/utils/image_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../../config/chat_feature_config.dart';

/// Bottom input bar for the chat screen.
///
/// Set [ChatFeatureConfig.enableImages] = true to show the image attach button.
/// Pass [onSendImage] with the picked file path when that flag is on.
class ChatInput extends StatefulWidget {
  final bool isEnabled;
  final void Function(String text) onSendText;

  /// Called with the absolute file path of the picked image.
  final void Function(String filePath)? onSendImage;

  /// Called on every keystroke — used to emit typing events.
  final VoidCallback? onTyping;

  const ChatInput({
    super.key,
    required this.onSendText,
    this.isEnabled = true,
    this.onSendImage,
    this.onTyping,
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

  Future<void> _pickImage() async {
    final picked = await ImagePickerService.pickSingle(context);
    if (picked == null) return;
    widget.onSendImage?.call(picked.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
          top: BorderSide(color: cs.outline.withOpacity(0.15)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Image attach button ──────────────────────────────────────
          if (ChatFeatureConfig.enableImages && widget.isEnabled)
            _MediaButton(
              icon: Icons.image_outlined,
              onTap: _pickImage,
            ),

          // ── Text field ───────────────────────────────────────────────
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: widget.isEnabled ? cs.surface : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.outline.withOpacity(0.2)),
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
                      ? AppLocalizations.of(context)!.typeMessage
                      : AppLocalizations.of(context)!.chatClosed,
                  hintStyle: TextStyle(
                    color: cs.onSurface.withOpacity(0.4),
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

          // ── Send button ──────────────────────────────────────────────
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