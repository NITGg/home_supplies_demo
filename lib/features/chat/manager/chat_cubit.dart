import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../../../core/utils/safe_emit_mixin.dart';
import '../config/chat_feature_config.dart';
import '../data/models/chat_model.dart';
import '../data/models/message_model.dart';
import '../data/repo/chat_repository.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> with SafeEmitMixin<ChatState> {
  final ChatRepository _repo;
  final int currentUserId;

  StreamSubscription<Map<String, dynamic>>? _newMessageSub;
  StreamSubscription<Map<String, dynamic>>? _typingStartSub;
  StreamSubscription<Map<String, dynamic>>? _typingStopSub;
  StreamSubscription<Map<String, dynamic>>? _messageReadSub;

  Timer? _typingDebounce;
  Timer? _typingTimeoutTimer;

  ChatCubit({required ChatRepository repo, required this.currentUserId})
      : _repo = repo,
        super(const ChatInitial()) {
    dLog('🟢 [ChatCubit] created — currentUserId: $currentUserId');
  }

  // ─── Open Existing Chat (from inbox) ─────────────────────────────────────

  Future<void> joinExistingChat(int chatId) async {
    dLog('🔵 [ChatCubit] joinExistingChat(chatId: $chatId)');
    safeEmit(const ChatLoading());
    try {
      final chats = await _repo.getMyChats();
      final knownChat = chats.cast<ChatModel?>().firstWhere(
            (c) => c?.id == chatId,
        orElse: () => null,
      );

      final result = await _repo.openChat(chatId, knownChat: knownChat);
      final messages = result.messages.reversed.toList();

      final effectiveChat = result.chat.id != 0
          ? result.chat
          : (knownChat ?? result.chat);

      _repo.joinChat(effectiveChat.id);
      _repo.markRead(effectiveChat.id);
      _subscribeToEvents(effectiveChat.id);

      safeEmit(
        ChatLoaded(
          chat: effectiveChat,
          messages: messages,
          hasMore: result.hasMoreMessages,
          isClosed: effectiveChat.isClosed,
        ),
      );
    } catch (e, st) {
      dLog('🔴 [ChatCubit] joinExistingChat error: $e\n$st');
      safeEmit(ChatError(e.toString()));
    }
  }

  // ─── Start New Chat ───────────────────────────────────────────────────────

  Future<void> openChat(int targetUserId, {int? orderId}) async {
    dLog('🔵 [ChatCubit] openChat(targetUserId: $targetUserId, orderId: $orderId)');
    safeEmit(const ChatLoading());
    try {
      final existingChats = await _repo.getMyChats();
      ChatModel? existingChat;
      for (final c in existingChats) {
        if (c.participants.map((p) => p.id).contains(targetUserId)) {
          existingChat = c;
          break;
        }
      }

      final ChatModel chat;
      if (existingChat != null) {
        chat = existingChat;
      } else {
        final result =
            await _repo.createOrGetChat(targetUserId, orderId: orderId);
        chat = result.chat;
      }

      final chatWithMsgs = await _repo.openChat(chat.id, knownChat: chat);
      final messages = chatWithMsgs.messages.reversed.toList();

      _repo.joinChat(chat.id);
      _repo.markRead(chat.id);
      _subscribeToEvents(chat.id);

      safeEmit(
        ChatLoaded(
          chat: chat,
          messages: messages,
          hasMore: chatWithMsgs.hasMoreMessages,
          isClosed: chat.isClosed,
        ),
      );
    } catch (e, st) {
      dLog('🔴 [ChatCubit] openChat error: $e\n$st');
      safeEmit(ChatError(e.toString()));
    }
  }

  // ─── Send Text Message ────────────────────────────────────────────────────

  Future<void> sendTextMessage(String content) async {
    if (state is! ChatLoaded) return;
    final loaded = state as ChatLoaded;
    if (loaded.isClosed) return;

    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final optimistic = MessageModel.optimistic(
      chatId: loaded.chat.id,
      senderId: currentUserId,
      content: trimmed,
      type: MessageType.text,
    );

    safeEmit(loaded.copyWith(messages: [...loaded.messages, optimistic]));
    _stopMyTyping(loaded.chat.id);

    try {
      final confirmed = await _repo.sendMessage(
        chatId: loaded.chat.id,
        content: trimmed,
        type: MessageType.text.toApiString(),
      );
      dLog(
        '✅ confirmed — serverId: ${confirmed.serverId}, content: ${confirmed.content}',
      );

      if (state is! ChatLoaded) return;
      final current = state as ChatLoaded;
      safeEmit(
        current.copyWith(
          messages: current.messages.map((m) {
            if (m.localId != optimistic.localId) return m;
            return m.copyWith(
              serverId: confirmed.serverId,
              status: MessageStatus.sent,
            );
          }).toList(),
        ),
      );
    } catch (e) {
      dLog('❌ [ChatCubit] sendTextMessage failed: $e');
      if (_isOrderEndedError(e)) {
        safeEmit(const ChatOrderEnded());
        return;
      }
      _markFailed(optimistic.localId, 'Failed to send message. Tap to retry.');
    }
  }

  // ─── Send Image Message ───────────────────────────────────────────────────

  Future<void> sendImageMessage(String filePath) async {
    if (state is! ChatLoaded) return;
    final loaded = state as ChatLoaded;
    if (loaded.isClosed) return;

    final optimistic = MessageModel.optimistic(
      chatId: loaded.chat.id,
      senderId: currentUserId,
      content: filePath,
      type: MessageType.image,
    );

    dLog(
      '📤 [ChatCubit] sendImageMessage — optimistic localId: ${optimistic.localId}',
    );
    safeEmit(loaded.copyWith(messages: [...loaded.messages, optimistic]));

    try {
      final confirmed = await _repo.sendImageMessage(
        chatId: loaded.chat.id,
        filePath: filePath,
      );
      dLog(
        '✅ [ChatCubit] sendImageMessage confirmed — url: ${confirmed.content}',
      );

      if (state is! ChatLoaded) return;
      final current = state as ChatLoaded;
      safeEmit(
        current.copyWith(
          messages: current.messages.map((m) {
            if (m.localId != optimistic.localId) return m;
            return MessageModel(
              localId: m.localId,
              serverId: confirmed.serverId,
              chatId: m.chatId,
              senderId: m.senderId,
              content: confirmed.content,
              type: MessageType.image,
              status: MessageStatus.sent,
              createdAt: m.createdAt,
              isMe: true,
            );
          }).toList(),
        ),
      );
    } catch (e) {
      dLog('❌ [ChatCubit] sendImageMessage failed: $e');
      if (_isOrderEndedError(e)) {
        safeEmit(const ChatOrderEnded());
        return;
      }
      _markFailed(optimistic.localId, 'Failed to send image. Tap to retry.');
    }
  }

  // ─── Retry a failed message ───────────────────────────────────────────────

  Future<void> retryMessage(String localId) async {
    dLog('🔄 [ChatCubit] retryMessage — localId: $localId');
    final raw = state is MessageSendFailed
        ? (state as MessageSendFailed).currentState
        : null;
    if (raw == null) return;

    final failed = raw.messages.cast<MessageModel?>().firstWhere(
          (m) => m?.localId == localId,
      orElse: () => null,
    );
    if (failed == null) return;

    final updated = raw.messages.map((m) {
      return m.localId == localId
          ? m.copyWith(status: MessageStatus.sending)
          : m;
    }).toList();
    safeEmit(raw.copyWith(messages: updated));

    try {
      if (failed.type == MessageType.image) {
        final confirmed = await _repo.sendImageMessage(
          chatId: raw.chat.id,
          filePath: failed.content,
        );
        if (state is! ChatLoaded) return;
        final current = state as ChatLoaded;
        safeEmit(
          current.copyWith(
            messages: current.messages.map((m) {
              if (m.localId != localId) return m;
              return MessageModel(
                localId: m.localId,
                serverId: confirmed.serverId,
                chatId: m.chatId,
                senderId: m.senderId,
                content: confirmed.content,
                type: MessageType.image,
                status: MessageStatus.sent,
                createdAt: m.createdAt,
                isMe: true,
              );
            }).toList(),
          ),
        );
      } else {
        final confirmed = await _repo.sendMessage(
          chatId: raw.chat.id,
          content: failed.content,
          type: failed.type.toApiString(),
        );
        if (state is! ChatLoaded) return;
        final current = state as ChatLoaded;
        safeEmit(
          current.copyWith(
            messages: current.messages.map((m) {
              if (m.localId != localId) return m;
              return m.copyWith(
                serverId: confirmed.serverId,
                status: MessageStatus.sent,
              );
            }).toList(),
          ),
        );
      }
    } catch (e) {
      dLog('❌ [ChatCubit] retryMessage failed: $e');
      if (_isOrderEndedError(e)) {
        safeEmit(const ChatOrderEnded());
        return;
      }
      if (state is! ChatLoaded) return;
      safeEmit(
        MessageSendFailed(
          currentState: state as ChatLoaded,
          failedMessageLocalId: localId,
          error: 'Failed to send. Tap to retry.',
        ),
      );
    }
  }

  // ─── Pagination ───────────────────────────────────────────────────────────

  Future<void> loadMoreMessages() async {
    if (state is! ChatLoaded) return;
    final loaded = state as ChatLoaded;
    if (loaded.isLoadingMore || !loaded.hasMore) return;

    safeEmit(loaded.copyWith(isLoadingMore: true));
    try {
      final older = await _repo.loadMoreMessages(
        loaded.chat.id,
        page: loaded.nextPage,
      );
      if (state is! ChatLoaded) return;
      final current = state as ChatLoaded;
      final existingIds = current.messages.map((m) => m.localId).toSet();
      final newOnes = older
          .reversed
          .where((m) => !existingIds.contains(m.localId))
          .toList();
      safeEmit(
        current.copyWith(
          messages: [...newOnes, ...current.messages],
          isLoadingMore: false,
          hasMore: older.length >= ChatFeatureConfig.messagesPageSize,
          nextPage: current.nextPage + 1,
        ),
      );
    } catch (e, st) {
      dLog('🔴 [ChatCubit] loadMoreMessages error: $e\n$st');
      if (state is ChatLoaded) {
        safeEmit((state as ChatLoaded).copyWith(isLoadingMore: false));
      }
    }
  }

  // ─── Typing ───────────────────────────────────────────────────────────────

  void onUserTyping() {
    if (state is! ChatLoaded) return;
    final chatId = (state as ChatLoaded).chat.id;
    _typingDebounce?.cancel();
    _repo.emitTyping(chatId);
    _typingDebounce = Timer(ChatFeatureConfig.typingDebounce, () {
      _stopMyTyping(chatId);
    });
  }

  void _stopMyTyping(int chatId) {
    _typingDebounce?.cancel();
    _repo.emitStopTyping(chatId);
  }

  // ─── Close / Leave ────────────────────────────────────────────────────────

  void closeChatForOrder() {
    if (state is! ChatLoaded) return;
    safeEmit((state as ChatLoaded).copyWith(isClosed: true));
  }

  void leaveChat() {
    if (state is! ChatLoaded) return;
    final chatId = (state as ChatLoaded).chat.id;
    _stopMyTyping(chatId);
    _repo.leaveChat(chatId);
  }

  // ─── Socket Subscriptions ─────────────────────────────────────────────────

  void _subscribeToEvents(int chatId) {
    _newMessageSub = _repo.onNewMessage.listen((raw) {
      final data = (raw['message'] is Map<String, dynamic>)
          ? raw['message'] as Map<String, dynamic>
          : raw;

      final incomingChatId = _intField(data, 'chat_id');
      if (incomingChatId != chatId) return;

      final ChatLoaded current;
      if (state is ChatLoaded) {
        current = state as ChatLoaded;
      } else if (state is MessageSendFailed) {
        current = (state as MessageSendFailed).currentState;
      } else {
        return;
      }

      final msgJson = _flattenSender(data);
      final msg = MessageModel.fromJson(msgJson, currentUserId: currentUserId);

      // ── Self-echo handling ─────────────────────────────────────────────────
      if (msg.isMe) {
        // Case 1: HTTP response already confirmed this message (serverId present).
        // The socket echo arrives late — nothing to do.
        if (msg.serverId != null &&
            current.messages.any((m) => m.serverId == msg.serverId)) {
          return;
        }

        // Case 2: Message is still in-flight (status=sending).
        // Confirm it via the socket echo instead of waiting for HTTP.
        final optimisticIdx = current.messages.lastIndexWhere(
              (m) =>
          m.status == MessageStatus.sending &&
              m.senderId == msg.senderId &&
              m.type == msg.type &&
              // Images: skip content check — local path ≠ server URL.
              (msg.type == MessageType.image || m.content == msg.content),
        );

        if (optimisticIdx != -1) {
          final updated = List<MessageModel>.from(current.messages);
          updated[optimisticIdx] = updated[optimisticIdx].copyWith(
            serverId: msg.serverId,
            status: MessageStatus.sent,
          );
          safeEmit(current.copyWith(messages: updated));
          _repo.markRead(chatId);
          return;
        }
      }

      // ── General dedup — by serverId only ──────────────────────────────────
      // Content-based matching is intentionally avoided: two different users
      // can send identical text, and dropping one would cause a desync.
      if (msg.serverId != null &&
          current.messages.any((m) => m.serverId == msg.serverId)) {
        return;
      }

      safeEmit(current.copyWith(messages: [...current.messages, msg]));
      _repo.markRead(chatId);
    });

    _typingStartSub = _repo.onUserTyping.listen((data) {
      final incomingChatId =
          _intField(data, 'chat_id') ?? _intField(data, 'chatId');
      if (incomingChatId != chatId) return;
      if (state is! ChatLoaded) return;

      final userId = _intField(data, 'user_id') ?? _intField(data, 'userId');
      if (userId == null || userId == currentUserId) return;

      final current = state as ChatLoaded;
      safeEmit(
        current.copyWith(
          typingUserIds: Set<int>.from(current.typingUserIds)..add(userId),
        ),
      );
      _resetTypingTimeout(chatId, userId);
    });

    _typingStopSub = _repo.onUserStoppedTyping.listen((data) {
      final incomingChatId =
          _intField(data, 'chat_id') ?? _intField(data, 'chatId');
      if (incomingChatId != chatId) return;
      if (state is! ChatLoaded) return;

      final userId = _intField(data, 'user_id') ?? _intField(data, 'userId');
      if (userId == null) return;
      _removeTypingUser(userId);
    });

    _messageReadSub = _repo.onMessageRead.listen((data) {
      final incomingChatId =
          _intField(data, 'chat_id') ?? _intField(data, 'chatId');
      if (incomingChatId != chatId) return;

      final ChatLoaded current;
      if (state is ChatLoaded) {
        current = state as ChatLoaded;
      } else if (state is MessageSendFailed) {
        current = (state as MessageSendFailed).currentState;
      } else {
        return;
      }

      final updated = current.messages.map((m) {
        if (m.isMe && m.status != MessageStatus.read) {
          return m.copyWith(status: MessageStatus.read);
        }
        return m;
      }).toList();

      safeEmit(current.copyWith(messages: updated));
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  bool _isOrderEndedError(Object e) {
    return e is DioException && e.response?.statusCode == 403;
  }

  void _markFailed(String localId, String error) {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;
    final updated = current.messages.map((m) {
      return m.localId == localId
          ? m.copyWith(status: MessageStatus.failed)
          : m;
    }).toList();
    safeEmit(
      MessageSendFailed(
        currentState: current.copyWith(messages: updated),
        failedMessageLocalId: localId,
        error: error,
      ),
    );
  }

  static int? _intField(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static Map<String, dynamic> _flattenSender(Map<String, dynamic> data) {
    final sender = data['sender'];
    if (sender is! Map) return data;
    final flat = Map<String, dynamic>.from(data);
    flat['sender_id'] ??= sender['id'];
    return flat;
  }

  void _resetTypingTimeout(int chatId, int userId) {
    _typingTimeoutTimer?.cancel();
    _typingTimeoutTimer = Timer(
      ChatFeatureConfig.typingIndicatorTimeout,
          () => _removeTypingUser(userId),
    );
  }

  void _removeTypingUser(int userId) {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;
    safeEmit(
      current.copyWith(
        typingUserIds: Set<int>.from(current.typingUserIds)..remove(userId),
      ),
    );
  }

  @override
  Future<void> close() async {
    _typingDebounce?.cancel();
    _typingTimeoutTimer?.cancel();
    await _newMessageSub?.cancel();
    await _typingStartSub?.cancel();
    await _typingStopSub?.cancel();
    await _messageReadSub?.cancel();
    return super.close();
  }
}