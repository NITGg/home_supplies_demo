//courier

import 'dart:developer';

/// Supported message content types.
///
/// Guarded by [ChatFeatureConfig] flags at the UI layer —
/// only [text] is guaranteed to be enabled at all times.
enum MessageType {
  text,
  voice,
  image,
  file;

  static MessageType fromString(String? raw) {
    return MessageType.values.firstWhere(
          (e) => e.name.toUpperCase() == (raw ?? 'TEXT').toUpperCase(),
      orElse: () => MessageType.text,
    );
  }

  String toApiString() => name.toUpperCase();
}

/// Tracks the send lifecycle of a message for optimistic UI.
enum MessageStatus {
  /// Locally created, not yet acknowledged by the server.
  sending,

  /// Server ack received — persisted.
  sent,

  /// Delivered to the recipient's device.
  delivered,

  /// Recipient has opened the chat and seen this message.
  read,

  /// Socket emit failed or server returned an error.
  failed;

  static MessageStatus fromString(String? raw) {
    return MessageStatus.values.firstWhere(
          (e) => e.name.toUpperCase() == (raw ?? 'SENT').toUpperCase(),
      orElse: () => MessageStatus.sent,
    );
  }
}

class MessageModel {
  /// Temporary client-side ID used before the server echoes back the real one.
  /// Format: `local_<timestamp>_<random>` for optimistic messages,
  /// or the server's ID (as String) once confirmed.
  final String localId;

  /// The real database ID. Null until the server acknowledges.
  final int? serverId;

  final int chatId;
  final int senderId;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime createdAt;

  /// Convenience flag — set at parse time using [currentUserId].
  final bool isMe;

  const MessageModel({
    required this.localId,
    this.serverId,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.isMe,
  });

  // ─── Factory: from server JSON ────────────────────────────────────────────
  factory MessageModel.fromJson(
      Map<String, dynamic> json, {
        required int currentUserId,
      }) {
    // ── Diagnostic: log every field and its runtime type ──────────────────
    log('🔍 [MessageModel.fromJson] raw json keys: ${json.keys.toList()}');
    log(
      '🔍 [MessageModel.fromJson] id: ${json['id']} (${json['id']?.runtimeType})',
    );
    log(
      '🔍 [MessageModel.fromJson] chat_id: ${json['chat_id']} (${json['chat_id']?.runtimeType})',
    );
    log(
      '🔍 [MessageModel.fromJson] sender_id: ${json['sender_id']} (${json['sender_id']?.runtimeType})',
    );
    log('🔍 [MessageModel.fromJson] content: ${json['content']}');
    log('🔍 [MessageModel.fromJson] type: ${json['type']}');
    log('🔍 [MessageModel.fromJson] status: ${json['status']}');
    log('🔍 [MessageModel.fromJson] created_at: ${json['created_at']}');

    // ── Safe int parsing ─────────────────────────────────────────────────
    // The server may return ints as num, int, or String depending on the
    // JSON encoder used. _toInt() handles all three safely.
    final senderObj = json['sender'];
    final senderId =
        _toInt(json['sender_id']) ??
            (senderObj is Map ? _toInt(senderObj['id']) : null);
    final chatId = _toInt(json['chat_id']);

    if (senderId == null) {
      log(
        '🚨 [MessageModel.fromJson] sender_id is null or unparseable! '
            'Full json: $json',
      );
    }
    if (chatId == null) {
      log(
        '🚨 [MessageModel.fromJson] chat_id is null or unparseable! '
            'Full json: $json',
      );
    }

    return MessageModel(
      localId:
      json['id']?.toString() ??
          'srv_${DateTime.now().millisecondsSinceEpoch}',
      serverId: _toInt(json['id']),
      chatId: chatId ?? 0,
      // 0 fallback keeps the app alive; log above surfaces it
      senderId: senderId ?? 0,
      content: json['content'] as String? ?? '',
      type: MessageType.fromString(json['type'] as String?),
      status: _statusFromJson(json, senderId: senderId ?? 0, currentUserId: currentUserId),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isMe: (senderId ?? 0) == currentUserId,
    );
  }

  static MessageStatus _statusFromJson(
      Map<String, dynamic> json, {
        required int senderId,
        required int currentUserId,
      }) {
    // Explicit status field takes priority (optimistic/retry flows)
    final raw = json['status'] as String?;
    if (raw != null) return MessageStatus.fromString(raw);

    // Server uses is_read boolean
    final isRead = json['is_read'] as bool? ?? false;
    final isMe = senderId == currentUserId;

    if (!isMe) return MessageStatus.delivered; // incoming — status irrelevant
    return isRead ? MessageStatus.read : MessageStatus.sent;
  }

  // ─── Factory: optimistic (before server ack) ──────────────────────────────
  factory MessageModel.optimistic({
    required int chatId,
    required int senderId,
    required String content,
    MessageType type = MessageType.text,
  }) {
    final now = DateTime.now();
    return MessageModel(
      localId: 'local_${now.millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: senderId,
      content: content,
      type: type,
      status: MessageStatus.sending,
      createdAt: now,
      isMe: true,
    );
  }

  // ─── copyWith ─────────────────────────────────────────────────────────────
  MessageModel copyWith({
    String? localId,
    int? serverId,
    MessageStatus? status,
  }) {
    return MessageModel(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      chatId: chatId,
      senderId: senderId,
      content: content,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      isMe: isMe,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': serverId,
    'local_id': localId,
    'chat_id': chatId,
    'sender_id': senderId,
    'content': content,
    'type': type.toApiString(),
    'status': status.name.toUpperCase(),
    'created_at': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MessageModel &&
              other.localId == localId &&
              other.status == status;

  @override
  int get hashCode => Object.hash(localId, status);

  @override
  String toString() =>
      'MessageModel(localId: $localId, senderId: $senderId, status: $status)';

  // ─── Helper ───────────────────────────────────────────────────────────────

  /// Safely parses int from int, num, or String. Returns null on failure.
  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
