import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../config/chat_feature_config.dart';
import '../data/models/chat_model.dart';
import '../data/models/message_model.dart';
import '../data/repo/chat_repository.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
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
    emit(const ChatLoading());
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

      emit(
        ChatLoaded(
          chat: effectiveChat,
          messages: messages,
          hasMore: result.hasMoreMessages,
          isClosed: effectiveChat.isClosed,
        ),
      );
    } catch (e, st) {
      dLog('🔴 [ChatCubit] joinExistingChat error: $e\n$st');
      emit(ChatError(e.toString()));
    }
  }

  // ─── Start New Chat ───────────────────────────────────────────────────────

  Future<void> openChat(int targetUserId) async {
    dLog('🔵 [ChatCubit] openChat(targetUserId: $targetUserId)');
    emit(const ChatLoading());
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
        final result = await _repo.createOrGetChat(targetUserId);
        chat = result.chat;
      }

      final chatWithMsgs = await _repo.openChat(chat.id, knownChat: chat);
      final messages = chatWithMsgs.messages.reversed.toList();

      _repo.joinChat(chat.id);
      _repo.markRead(chat.id);
      _subscribeToEvents(chat.id);

      emit(
        ChatLoaded(
          chat: chat,
          messages: messages,
          hasMore: chatWithMsgs.hasMoreMessages,
          isClosed: chat.isClosed,
        ),
      );
    } catch (e, st) {
      dLog('🔴 [ChatCubit] openChat error: $e\n$st');
      emit(ChatError(e.toString()));
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

    emit(loaded.copyWith(messages: [...loaded.messages, optimistic]));
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
      emit(
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
      _markFailed(optimistic.localId, 'Failed to send message. Tap to retry.');
    }
  }

  // ─── Send Image Message ───────────────────────────────────────────────────

  /// [filePath] is the absolute path to the picked image on disk.
  /// Shows a local-file preview bubble immediately, then replaces it
  /// with the server URL once the upload completes.
  Future<void> sendImageMessage(String filePath) async {
    if (state is! ChatLoaded) return;
    final loaded = state as ChatLoaded;
    if (loaded.isClosed) return;

    // Optimistic: use the local file path as content for immediate preview.
    final optimistic = MessageModel.optimistic(
      chatId: loaded.chat.id,
      senderId: currentUserId,
      content: filePath, // local path — bubble renders as Image.file
      type: MessageType.image,
    );

    dLog(
      '📤 [ChatCubit] sendImageMessage — optimistic localId: ${optimistic.localId}',
    );
    emit(loaded.copyWith(messages: [...loaded.messages, optimistic]));

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
      emit(
        current.copyWith(
          messages: current.messages.map((m) {
            if (m.localId != optimistic.localId) return m;
            // Replace local path with the server URL.
            return MessageModel(
              localId: m.localId,
              serverId: confirmed.serverId,
              chatId: m.chatId,
              senderId: m.senderId,
              content: confirmed.content,
              // ← server URL
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
    emit(raw.copyWith(messages: updated));

    try {
      if (failed.type == MessageType.image) {
        // Re-upload the local file.
        final confirmed = await _repo.sendImageMessage(
          chatId: raw.chat.id,
          filePath: failed.content,
        );
        if (state is! ChatLoaded) return;
        final current = state as ChatLoaded;
        emit(
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
        emit(
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
      if (state is! ChatLoaded) return;
      emit(
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

    emit(loaded.copyWith(isLoadingMore: true));
    try {
      final older = await _repo.loadMoreMessages(
        loaded.chat.id,
        page: loaded.nextPage,
      );
      if (state is! ChatLoaded) return;
      final current = state as ChatLoaded;
      final existingIds = current.messages.map((m) => m.localId).toSet();
      final newOnes = older
          .reversed // ← add this
          .where((m) => !existingIds.contains(m.localId))
          .toList();
      emit(
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
        emit((state as ChatLoaded).copyWith(isLoadingMore: false));
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
    emit((state as ChatLoaded).copyWith(isClosed: true));
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

      // Echo of our own optimistic message.
      if (msg.isMe) {
        final optimisticIdx = current.messages.lastIndexWhere(
          (m) =>
              m.status == MessageStatus.sending &&
              m.senderId == msg.senderId &&
              m.type == msg.type &&
              // For text: match content exactly.
              // For images: skip content check — local file path ≠ server URL.
              (msg.type == MessageType.image || m.content == msg.content),
        );

        if (optimisticIdx != -1) {
          final updated = List<MessageModel>.from(current.messages);
          updated[optimisticIdx] = updated[optimisticIdx].copyWith(
            serverId: msg.serverId,
            status: MessageStatus.sent,
          );
          emit(current.copyWith(messages: updated));
          _repo.markRead(chatId);
          return;
        }
      }

      if (current.messages.any(
        (m) =>
            (m.serverId != null && m.serverId == msg.serverId) ||
            (m.isMe && m.type == msg.type && m.content == msg.content),
      )) {
        return;
      }

      emit(current.copyWith(messages: [...current.messages, msg]));
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
      emit(
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
      final incomingChatId = _intField(data, 'chat_id') ?? _intField(data, 'chatId');
      if (incomingChatId != chatId) return;

      final ChatLoaded current;
      if (state is ChatLoaded) {
        current = state as ChatLoaded;
      } else if (state is MessageSendFailed) {
        current = (state as MessageSendFailed).currentState;
      } else return;

      final updated = current.messages.map((m) {
        if (m.isMe && m.status != MessageStatus.read) {
          return m.copyWith(status: MessageStatus.read);
        }
        return m;
      }).toList();

      emit(current.copyWith(messages: updated));
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _markFailed(String localId, String error) {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;
    final updated = current.messages.map((m) {
      return m.localId == localId
          ? m.copyWith(status: MessageStatus.failed)
          : m;
    }).toList();
    emit(
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
    emit(
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
