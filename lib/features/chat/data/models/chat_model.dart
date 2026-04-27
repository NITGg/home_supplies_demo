import 'dart:developer';

import 'chat_user_model.dart';
import 'message_model.dart';

/// Represents a 1:1 chat between two participants.
class ChatModel {
  final int id;
  final List<ChatUserModel> participants;
  final MessageModel? lastMessage;
  final int unreadCount;

  /// True when the associated order has been confirmed/completed.
  /// After this point, the input is disabled and no new messages can be sent.
  final bool isClosed;

  final DateTime? updatedAt;

  const ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    this.isClosed = false,
    this.updatedAt,
  });

  factory ChatModel.fromJson(
      Map<String, dynamic> json, {
        required int currentUserId,
      }) {
    log('🔍 [ChatModel.fromJson] keys: ${json.keys.toList()}');
    log('🔍 [ChatModel.fromJson] id: ${json['id']} (${json['id']?.runtimeType}), '
        'is_closed: ${json['is_closed']} (${json['is_closed']?.runtimeType}), '
        'participants: ${json['participants']?.runtimeType}');

    // ── Participants ──────────────────────────────────────────────────────────
    // The server returns participants as pivot rows:
    //   { id, chat_id, user_id, joined_at, left_at }
    // Full user info (name, photo) lives in the `creator` field.
    // We build ChatUserModel entries using user_id as the id, and fill in
    // name/avatar from `creator` when the user_id matches.
    final rawParticipants = json['participants'] as List<dynamic>? ?? [];
    final creatorJson = json['creator'] as Map<String, dynamic>?;

    final participants = rawParticipants.map((p) {
      final pivot = p as Map<String, dynamic>;
      final userId = _toInt(pivot['user_id']) ?? _toInt(pivot['id']) ?? 0;

      // If the creator data matches this participant, use it for name/avatar.
      final creatorId = _toInt(creatorJson?['id']);
      if (creatorJson != null && creatorId == userId) {
        return ChatUserModel(
          id: userId,
          name: (creatorJson['full_name'] as String?)?.trim() ??
              (creatorJson['name'] as String?)?.trim() ??
              'User',
          avatarUrl: creatorJson['personal_photo'] as String? ??
              creatorJson['avatar'] as String? ??
              creatorJson['avatar_url'] as String?,
        );
      }

      // Fallback: we only have the user_id, no display info.
      return ChatUserModel(id: userId, name: 'User');
    }).toList();

    // ── Last message ──────────────────────────────────────────────────────────
    // Shape A: last_message field (single object).
    // Shape B: messages array — take the last item.
    final lastMsgJson = json['last_message'] as Map<String, dynamic>? ??
        (() {
          final msgs = json['messages'] as List<dynamic>?;
          return msgs != null && msgs.isNotEmpty
              ? msgs.last as Map<String, dynamic>?
              : null;
        })();

    final id = _toInt(json['id']);
    if (id == null) {
      log('🚨 [ChatModel.fromJson] id is null! Full json: $json');
    }

    return ChatModel(
      id: id ?? 0,
      participants: participants,
      lastMessage: lastMsgJson != null
          ? MessageModel.fromJson(lastMsgJson, currentUserId: currentUserId)
          : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      isClosed: json['is_closed'] as bool? ?? false,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  /// Returns the participant who is NOT the current user.
  ChatUserModel? otherParticipant(int currentUserId) {
    try {
      return participants.firstWhere((p) => p.id != currentUserId);
    } catch (_) {
      return participants.isNotEmpty ? participants.first : null;
    }
  }

  ChatModel copyWith({
    int? unreadCount,
    MessageModel? lastMessage,
    bool? isClosed,
  }) {
    return ChatModel(
      id: id,
      participants: participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isClosed: isClosed ?? this.isClosed,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ChatModel(id: $id, unread: $unreadCount, closed: $isClosed)';

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

// ─── Wrapper for GET /chat/get-chat/:chatId ───────────────────────────────────

class ChatWithMessagesModel {
  final ChatModel chat;
  final List<MessageModel> messages;
  final bool hasMoreMessages;
  final int? nextPage;

  const ChatWithMessagesModel({
    required this.chat,
    required this.messages,
    required this.hasMoreMessages,
    this.nextPage,
  });

  factory ChatWithMessagesModel.fromJson(
      Map<String, dynamic> json, {
        required int currentUserId,
        // Provide the already-known chat when the server returns a messages-only
        // shape (no id / participants in the response).
        ChatModel? knownChat,
        // Current page number — used to correctly compute hasMore from totalPages.
        int currentPage = 1,
      }) {
    log('🔍 [ChatWithMessagesModel.fromJson] keys: ${json.keys.toList()}');

    // ── Detect response shape ─────────────────────────────────────────────────
    // Messages-only shape: { totalMessages, totalPages, messages: [...] }
    // Full shape:          { id, participants, ..., messages: [...] }
    final isMessagesOnly = json.containsKey('totalMessages') ||
        (json.containsKey('messages') && !json.containsKey('id'));

    final ChatModel chat;
    if (isMessagesOnly) {
      // Use the caller-supplied chat object; fall back to a safe placeholder.
      // ChatCubit always passes knownChat so id is never 0 in practice.
      chat = knownChat ?? ChatModel(id: 0, participants: [], isClosed: false);
      log('🔍 [ChatWithMessagesModel.fromJson] messages-only shape — '
          'using ${knownChat != null ? "knownChat id:${knownChat.id}" : "placeholder"}');
    } else {
      chat = ChatModel.fromJson(json, currentUserId: currentUserId);
    }

    // ── Parse messages ────────────────────────────────────────────────────────
    final msgData = json['messages'];
    log('🔍 [ChatWithMessagesModel.fromJson] messages field type: ${msgData?.runtimeType}');

    List<dynamic> rawMessages = [];
    bool hasMore = false;
    int? nextPage;

    if (msgData is List) {
      rawMessages = msgData;
      // totalPages is provided by the messages-only shape.
      final totalPages = (json['totalPages'] as num?)?.toInt() ?? 1;
      hasMore = currentPage < totalPages;
      if (hasMore) nextPage = currentPage + 1;
    } else if (msgData is Map<String, dynamic>) {
      rawMessages = msgData['data'] as List<dynamic>? ?? [];
      final pagination = msgData['pagination'] as Map<String, dynamic>?;
      if (pagination != null) {
        final current = (pagination['current_page'] as num?)?.toInt() ?? 1;
        final last = (pagination['last_page'] as num?)?.toInt() ?? 1;
        hasMore = current < last;
        if (hasMore) nextPage = current + 1;
      }
    }

    log('🔍 [ChatWithMessagesModel.fromJson] '
        'rawMessages: ${rawMessages.length}, hasMore: $hasMore, nextPage: $nextPage');

    final messages = rawMessages
        .map((m) => MessageModel.fromJson(
      m as Map<String, dynamic>,
      currentUserId: currentUserId,
    ))
        .toList();

    return ChatWithMessagesModel(
      chat: chat,
      messages: messages,
      hasMoreMessages: hasMore,
      nextPage: nextPage,
    );
  }
}