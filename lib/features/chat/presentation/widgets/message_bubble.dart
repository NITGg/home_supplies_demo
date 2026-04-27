import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;

  /// Called when the user taps a [MessageStatus.failed] bubble.
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: GestureDetector(
          onTap: message.status == MessageStatus.failed ? onRetry : null,
          child: Container(
            margin: EdgeInsets.only(
              left: message.isMe ? 48 : 0,
              right: message.isMe ? 0 : 48,
              top: 2,
              bottom: 2,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _bubbleColor(context),
              borderRadius: _bubbleRadius(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Content ──────────────────────────────────────────────
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 15,
                    color: message.isMe
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                // ── Timestamp + status ───────────────────────────────────
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: message.isMe
                            ? Colors.white70
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                      ),
                    ),
                    if (message.isMe) ...[
                      const SizedBox(width: 4),
                      _StatusIcon(status: message.status),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _bubbleColor(BuildContext context) {
    if (message.status == MessageStatus.failed) return Colors.red.shade100;
    if (message.isMe) return Theme.of(context).colorScheme.primary;
    return Theme.of(context).colorScheme.surfaceVariant;
  }

  BorderRadius _bubbleRadius() {
    const r = Radius.circular(18);
    const rSmall = Radius.circular(4);
    return message.isMe
        ? const BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: r,
            bottomRight: rSmall,
          )
        : const BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomRight: r,
            bottomLeft: rSmall,
          );
  }

  String _formatTime(DateTime dt) => DateFormat.jm().format(dt.toLocal());
}

// ─── Status Tick Icon ─────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white70,
          ),
        );
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 14, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 14, color: Colors.redAccent);
    }
  }
}
