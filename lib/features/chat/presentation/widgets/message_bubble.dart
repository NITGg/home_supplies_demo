import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import '../../data/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
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
            decoration: BoxDecoration(
              color: _bubbleColor(context),
              borderRadius: _bubbleRadius(),
            ),
            child: message.type == MessageType.image
                ? _ImageContent(message: message)
                : _TextContent(message: message),
          ),
        ),
      ),
    );
  }

  Color _bubbleColor(BuildContext context) {
    if (message.status == MessageStatus.failed) return Colors.red.shade100;
    if (message.type == MessageType.image) return Colors.transparent;
    if (message.isMe) return Theme.of(context).colorScheme.primary;
    return Theme.of(context).colorScheme.surfaceVariant;
  }

  BorderRadius _bubbleRadius() {
    const r = Radius.circular(18);
    const rSmall = Radius.circular(4);
    return message.isMe
        ? const BorderRadius.only(
        topLeft: r, topRight: r, bottomLeft: r, bottomRight: rSmall)
        : const BorderRadius.only(
        topLeft: r, topRight: r, bottomRight: r, bottomLeft: rSmall);
  }
}

// ─── Text bubble content ──────────────────────────────────────────────────────

class _TextContent extends StatelessWidget {
  final MessageModel message;
  const _TextContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
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
          _TimestampRow(message: message),
        ],
      ),
    );
  }
}

// ─── Image bubble content ─────────────────────────────────────────────────────

class _ImageContent extends StatelessWidget {
  final MessageModel message;
  const _ImageContent({required this.message});

  /// True when we are still showing the local optimistic preview
  /// (content is a file path, not a URL).
  bool get _isLocalFile =>
      message.content.startsWith('/') || message.content.startsWith('file://');

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: _bubbleRadius(),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _openImageViewer(context),
            child: _isLocalFile
                ? Image.file(
              File(message.content.replaceFirst('file://', '')),
              width: MediaQuery.of(context).size.width * 0.65,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(context),
            )
                : Image.network(
              message.content,
              width: MediaQuery.of(context).size.width * 0.65,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(context),
            ),
          ),

          // ── Uploading overlay ─────────────────────────────────────────
          if (message.status == MessageStatus.sending)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),

          // ── Failed overlay ────────────────────────────────────────────
          if (message.status == MessageStatus.failed)
            Positioned.fill(
              child: Container(
                color: Colors.black38,
                child: const Center(
                  child: Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 36),
                ),
              ),
            ),

          // ── Timestamp + status ────────────────────────────────────────
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _TimestampRow(message: message, lightTheme: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.65,
      height: 180,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
      ),
    );
  }

  BorderRadius _bubbleRadius() {
    const r = Radius.circular(18);
    const rSmall = Radius.circular(4);
    return message.isMe
        ? const BorderRadius.only(
        topLeft: r, topRight: r, bottomLeft: r, bottomRight: rSmall)
        : const BorderRadius.only(
        topLeft: r, topRight: r, bottomRight: r, bottomLeft: rSmall);
  }

  void _openImageViewer(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: PhotoView(
                  backgroundDecoration:
                  const BoxDecoration(color: Colors.black),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  imageProvider: _isLocalFile
                      ? FileImage(
                    File(message.content.replaceFirst('file://', '')),
                  )
                      : NetworkImage(message.content) as ImageProvider,
                ),
              ),

              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Shared timestamp + status row ───────────────────────────────────────────

class _TimestampRow extends StatelessWidget {
  final MessageModel message;
  final bool lightTheme;

  const _TimestampRow({required this.message, this.lightTheme = false});

  @override
  Widget build(BuildContext context) {
    final color = lightTheme
        ? Colors.white
        : (message.isMe
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat.jm().format(message.createdAt.toLocal()),
          style: TextStyle(fontSize: 11, color: color),
        ),
        if (message.isMe) ...[
          const SizedBox(width: 4),
          _StatusIcon(status: message.status, color: color),
        ],
      ],
    );
  }
}

// ─── Status icon ─────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  final Color color;

  const _StatusIcon({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: color),
        );
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: color);
      case MessageStatus.read:
        return const Icon(Icons.done_all,
            size: 14, color: Colors.lightBlueAccent);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline,
            size: 14, color: Colors.redAccent);
    }
  }
}