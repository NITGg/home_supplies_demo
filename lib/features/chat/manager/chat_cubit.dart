import 'dart:async';
import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../config/chat_feature_config.dart';
import '../data/models/chat_model.dart';
import '../data/models/message_model.dart';
import '../data/repo/chat_repository.dart';
import 'chat_state.dart';

/// Handles all logic for a single open chat screen.
///
/// Lifecycle:
///   1. Call [openChat] (new) or [joinExistingChat] (from inbox).
///   2. Listen to state: [ChatLoaded] drives the UI.
///   3. Call [leaveChat] when the screen is popped.
///
/// This cubit is completely generic — inject [currentUserId] so it works
/// identically in the courier app and the customer app.
class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _repo;
  final int currentUserId;

  StreamSubscription<Map<String, dynamic>>? _newMessageSub;
  StreamSubscription<Map<String, dynamic>>? _typingStartSub;
  StreamSubscription<Map<String, dynamic>>? _typingStopSub;

  /// Debounce timer for emitting [chat:stop_typing].
  Timer? _typingDebounce;

  /// Auto-hide timer for the incoming typing indicator.
  Timer? _typingTimeoutTimer;

  ChatCubit({
    required ChatRepository repo,
    required this.currentUserId,
  })  : _repo = repo,
        super(const ChatInitial()) {
    log('🟢 [ChatCubit] created — currentUserId: $currentUserId');
  }

  // ─── Open Existing Chat (from inbox) ─────────────────────────────────────

  Future<void> joinExistingChat(int chatId) async {
    log('🔵 [ChatCubit] joinExistingChat(chatId: $chatId)');
    emit(const ChatLoading());
    try {
      // Fetch chat list first so we can pass the known ChatModel to openChat.
      // This ensures the messages-only server response is parsed with the
      // correct chat id rather than falling back to id:0.
      final chats = await _repo.getMyChats();
      final knownChat = chats.cast<ChatModel?>()
          .firstWhere((c) => c?.id == chatId, orElse: () => null);

      log('🔵 [ChatCubit] calling _repo.openChat($chatId)...');
      final result = await _repo.openChat(chatId, knownChat: knownChat);

      // Server returns messages newest-first; reverse so oldest is at index 0
      // (the ListView is reversed:true so index 0 renders at the bottom).
      final messages = result.messages.reversed.toList();

      log('🔵 [ChatCubit] openChat returned — '
          'chat.id: ${result.chat.id}, '
          'isClosed: ${result.chat.isClosed}, '
          'messageCount: ${messages.length}, '
          'hasMore: ${result.hasMoreMessages}');

      final effectiveChat = result.chat.id != 0
          ? result.chat
          : (knownChat ?? result.chat);

      _repo.joinChat(effectiveChat.id);
      _repo.markRead(effectiveChat.id);
      _subscribeToEvents(effectiveChat.id);

      emit(ChatLoaded(
        chat: effectiveChat,
        messages: messages,
        hasMore: result.hasMoreMessages,
        isClosed: effectiveChat.isClosed,
      ));
      log('🔵 [ChatCubit] emitting ChatLoaded — chatId: ${effectiveChat.id}, '
          'isClosed: ${effectiveChat.isClosed}');
    } catch (e, st) {
      log('🔴 [ChatCubit] joinExistingChat error: $e\n$st');
      emit(ChatError(e.toString()));
    }
  }

  // ─── Start New Chat (tap "Message" on a user profile) ────────────────────

  Future<void> openChat(int targetUserId) async {
    log('🔵 [ChatCubit] openChat(targetUserId: $targetUserId)');
    emit(const ChatLoading());
    try {
      // ── Step 1: find an existing chat with this user ──────────────────────
      // getMyChats returns full participant lists so we can match locally
      // without relying on the server's create-or-get deduplication.
      log('🔵 [ChatCubit] fetching existing chats to find one with $targetUserId...');
      final existingChats = await _repo.getMyChats();
      ChatModel? existingChat;
      for (final c in existingChats) {
        final participantIds = c.participants.map((p) => p.id).toSet();
        if (participantIds.contains(targetUserId)) {
          existingChat = c;
          log('🔵 [ChatCubit] found existing chat id: ${c.id}');
          break;
        }
      }

      // ── Step 2: create only if no existing chat was found ─────────────────
      final ChatModel chat;
      if (existingChat != null) {
        chat = existingChat;
      } else {
        log('🔵 [ChatCubit] no existing chat — calling createOrGetChat($targetUserId)');
        final result = await _repo.createOrGetChat(targetUserId);
        chat = result.chat;
        log('🔵 [ChatCubit] created chat id: ${chat.id}');
      }

      // ── Step 3: load messages ──────────────────────────────────────────────
      log('🔵 [ChatCubit] calling _repo.openChat(${chat.id})...');
      final chatWithMsgs = await _repo.openChat(chat.id, knownChat: chat);

      // Server returns messages newest-first; reverse so oldest is at index 0.
      final messages = chatWithMsgs.messages.reversed.toList();

      log('🔵 [ChatCubit] openChat(${chat.id}) returned — '
          'messageCount: ${messages.length}, '
          'hasMore: ${chatWithMsgs.hasMoreMessages}');

      _repo.joinChat(chat.id);
      _repo.markRead(chat.id);
      _subscribeToEvents(chat.id);

      emit(ChatLoaded(
        chat: chat,
        messages: messages,
        hasMore: chatWithMsgs.hasMoreMessages,
        isClosed: chat.isClosed,
      ));
      log('🔵 [ChatCubit] emitting ChatLoaded — chatId: ${chat.id}, '
          'messages: ${chatWithMsgs.messages.length}');
    } catch (e, st) {
      log('🔴 [ChatCubit] openChat error: $e\n$st');
      emit(ChatError(e.toString()));
    }
  }

  // ─── Send Message ─────────────────────────────────────────────────────────

  Future<void> sendTextMessage(String content) async {
    if (state is! ChatLoaded) return;
    final loaded = state as ChatLoaded;
    if (loaded.isClosed) {
      log('⚠️ [ChatCubit] sendTextMessage blocked — chat is closed');
      return;
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    // 1. Create an optimistic message and add it to the list immediately.
    final optimistic = MessageModel.optimistic(
      chatId: loaded.chat.id,
      senderId: currentUserId,
      content: trimmed,
      type: MessageType.text,
    );

    log('📤 [ChatCubit] sendTextMessage — optimistic localId: ${optimistic.localId}');

    emit(loaded.copyWith(
      messages: [...loaded.messages, optimistic],
    ));

    // Stop typing indicator for ourselves.
    _stopMyTyping(loaded.chat.id);

    // 2. Send via HTTP.
    try {
      final confirmed = await _repo.sendMessage(
        chatId: loaded.chat.id,
        content: trimmed,
        type: MessageType.text.toApiString(),
      );
      log('✅ [ChatCubit] sendMessage confirmed — serverId: ${confirmed.serverId}');

      if (state is! ChatLoaded) return;
      final current = state as ChatLoaded;
      final updated = current.messages.map((m) {
        if (m.localId != optimistic.localId) return m;
        return m.copyWith(
          serverId: confirmed.serverId,
          status: MessageStatus.sent,
        );
      }).toList();
      emit(current.copyWith(messages: updated));
    } catch (e) {
      log('❌ [ChatCubit] sendMessage failed: $e');
      if (state is! ChatLoaded) return;
      final current = state as ChatLoaded;
      final updated = current.messages.map((m) {
        if (m.localId != optimistic.localId) return m;
        return m.copyWith(status: MessageStatus.failed);
      }).toList();
      emit(MessageSendFailed(
        currentState: current.copyWith(messages: updated),
        failedMessageLocalId: optimistic.localId,
        error: 'Failed to send message. Tap to retry.',
      ));
    }
  }

  // ─── Retry a failed message ───────────────────────────────────────────────

  Future<void> retryMessage(String localId) async {
    log('🔄 [ChatCubit] retryMessage — localId: $localId');
    final raw =
    state is MessageSendFailed ? (state as MessageSendFailed).currentState : null;
    if (raw == null) return;

    final failed =
    raw.messages.cast<MessageModel?>().firstWhere(
          (m) => m?.localId == localId,
      orElse: () => null,
    );
    if (failed == null) return;

    // Reset to sending status.
    final updated = raw.messages.map((m) {
      return m.localId == localId ? m.copyWith(status: MessageStatus.sending) : m;
    }).toList();
    emit(raw.copyWith(messages: updated));

    try {
      final confirmed = await _repo.sendMessage(
        chatId: raw.chat.id,
        content: failed.content,
        type: failed.type.toApiString(),
      );
      log('✅ [ChatCubit] retryMessage confirmed — serverId: ${confirmed.serverId}');

      if (state is! ChatLoaded) return;
      final current = state as ChatLoaded;
      emit(current.copyWith(
        messages: current.messages.map((m) {
          if (m.localId != localId) return m;
          return m.copyWith(serverId: confirmed.serverId, status: MessageStatus.sent);
        }).toList(),
      ));
    } catch (e) {
      log('❌ [ChatCubit] retryMessage failed: $e');
      if (state is! ChatLoaded) return;
      emit(MessageSendFailed(
        currentState: state as ChatLoaded,
        failedMessageLocalId: localId,
        error: 'Failed to send message. Tap to retry.',
      ));
    }
  }

  // ─── Pagination ───────────────────────────────────────────────────────────

  Future<void> loadMoreMessages() async {
    if (state is! ChatLoaded) return;
    final loaded = state as ChatLoaded;
    if (loaded.isLoadingMore || !loaded.hasMore) return;

    log('🔵 [ChatCubit] loadMoreMessages — page: ${loaded.nextPage}');
    emit(loaded.copyWith(isLoadingMore: true));

    try {
      final older = await _repo.loadMoreMessages(
        loaded.chat.id,
        page: loaded.nextPage,
      );
      log('🔵 [ChatCubit] loadMoreMessages loaded ${older.length} older messages');

      if (state is! ChatLoaded) return;
      final current = state as ChatLoaded;

      // Deduplicate: some servers may overlap pages.
      final existingIds = current.messages.map((m) => m.localId).toSet();
      final newOnes = older.where((m) => !existingIds.contains(m.localId));

      emit(current.copyWith(
        messages: [...newOnes, ...current.messages],
        isLoadingMore: false,
        hasMore: older.length >= ChatFeatureConfig.messagesPageSize,
        nextPage: current.nextPage + 1,
      ));
    } catch (e, st) {
      log('🔴 [ChatCubit] loadMoreMessages error: $e\n$st');
      if (state is ChatLoaded) {
        emit((state as ChatLoaded).copyWith(isLoadingMore: false));
      }
    }
  }

  // ─── Typing ───────────────────────────────────────────────────────────────

  void onUserTyping() {
    if (state is! ChatLoaded) return;
    final chatId = (state as ChatLoaded).chat.id;

    // Cancel existing debounce.
    _typingDebounce?.cancel();

    _repo.emitTyping(chatId);

    // After debounce duration with no new keystrokes, emit stop_typing.
    _typingDebounce = Timer(ChatFeatureConfig.typingDebounce, () {
      _stopMyTyping(chatId);
    });
  }

  void _stopMyTyping(int chatId) {
    _typingDebounce?.cancel();
    _repo.emitStopTyping(chatId);
  }

  // ─── Close Chat (order confirmed) ─────────────────────────────────────────

  void closeChatForOrder() {
    log('🔵 [ChatCubit] closeChatForOrder called');
    if (state is! ChatLoaded) return;
    emit((state as ChatLoaded).copyWith(isClosed: true));
  }

  // ─── Leave Chat (screen pop) ─────────────────────────────────────────────

  void leaveChat() {
    log('🔵 [ChatCubit] leaveChat called');
    if (state is! ChatLoaded) return;
    final chatId = (state as ChatLoaded).chat.id;
    _stopMyTyping(chatId);
    _repo.leaveChat(chatId);
  }

  // ─── Socket Subscriptions ─────────────────────────────────────────────────

  void _subscribeToEvents(int chatId) {
    log('🔵 [ChatCubit] _subscribeToEvents for chatId: $chatId');

    // ── Incoming messages ──────────────────────────────────────────────────
    _newMessageSub = _repo.onNewMessage.listen((raw) {
      log('💬 [ChatCubit] onNewMessage received: $raw');

      // The server wraps the payload: { "message": { "chat_id": 5, ... } }
      // Unwrap it so the rest of the code always sees flat message fields.
      final data = (raw['message'] is Map<String, dynamic>)
          ? raw['message'] as Map<String, dynamic>
          : raw;

      final incomingChatId = _intField(data, 'chat_id');
      if (incomingChatId != chatId) {
        log('💬 [ChatCubit] onNewMessage ignored — belongs to chat $incomingChatId, current: $chatId');
        return;
      }

      // Accept both ChatLoaded and MessageSendFailed (late echo after timeout).
      final ChatLoaded current;
      if (state is ChatLoaded) {
        current = state as ChatLoaded;
      } else if (state is MessageSendFailed) {
        current = (state as MessageSendFailed).currentState;
      } else {
        return;
      }

      // Flatten sender info if the server nests it under a "sender" key.
      final Map<String, dynamic> msgJson = _flattenSender(data);
      final msg = MessageModel.fromJson(msgJson, currentUserId: currentUserId);

      // ── Case 1: echo of our own optimistic message ─────────────────────
      // The task-isolate transport doesn't relay acks, so we use the
      // server's new_message broadcast as the confirmation signal.
      if (msg.isMe) {
        final optimisticIdx = current.messages.lastIndexWhere((m) =>
        m.status == MessageStatus.sending &&
            m.content == msg.content &&
            m.senderId == msg.senderId);

        if (optimisticIdx != -1) {
          final localId = current.messages[optimisticIdx].localId;
          log('✅ [ChatCubit] onNewMessage confirmed optimistic localId: $localId '
              '→ serverId: ${msg.serverId}');
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

      // ── Case 2: duplicate check for already-confirmed messages ─────────
      final alreadyExists = current.messages.any((m) =>
      m.serverId != null && m.serverId == msg.serverId);
      if (alreadyExists) {
        log('💬 [ChatCubit] onNewMessage deduplicated — serverId: ${msg.serverId}');
        return;
      }

      // ── Case 3: genuinely new incoming message ─────────────────────────
      log('💬 [ChatCubit] onNewMessage appending — serverId: ${msg.serverId}, isMe: ${msg.isMe}');
      emit(current.copyWith(messages: [...current.messages, msg]));
      _repo.markRead(chatId);
    });

    // ── Typing: start ─────────────────────────────────────────────────────
    _typingStartSub = _repo.onUserTyping.listen((data) {
      // Server may send chatId (camelCase) or chat_id (snake_case).
      final incomingChatId = _intField(data, 'chat_id') ?? _intField(data, 'chatId');
      if (incomingChatId != chatId) return;
      if (state is! ChatLoaded) return;

      // Server may send userId (camelCase) or user_id (snake_case).
      final userId = _intField(data, 'user_id') ?? _intField(data, 'userId');
      if (userId == null || userId == currentUserId) return;

      log('✏️  [ChatCubit] typing start — userId: $userId');
      final current = state as ChatLoaded;
      final updated = Set<int>.from(current.typingUserIds)..add(userId);
      emit(current.copyWith(typingUserIds: updated));

      // Auto-hide if the server never emits stop_typing.
      _resetTypingTimeout(chatId, userId);
    });

    // ── Typing: stop ──────────────────────────────────────────────────────
    _typingStopSub = _repo.onUserStoppedTyping.listen((data) {
      final incomingChatId = _intField(data, 'chat_id') ?? _intField(data, 'chatId');
      if (incomingChatId != chatId) return;
      if (state is! ChatLoaded) return;

      final userId = _intField(data, 'user_id') ?? _intField(data, 'userId');
      if (userId == null) return;

      log('⏹️  [ChatCubit] typing stop — userId: $userId');
      _removeTypingUser(userId);
    });
  }

  // ── Payload normalisation helpers ──────────────────────────────────────────

  /// Reads an int field from [map] tolerating int, num, and String values.
  static int? _intField(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// If the server nests sender info under a "sender" key, copies the
  /// relevant fields up to the top level so [MessageModel.fromJson] can
  /// find sender_id without knowing the server's exact envelope shape.
  ///
  /// Input:  { id, chat_id, sender_id?, content, sender: { id, full_name, ... } }
  /// Output: { id, chat_id, sender_id, content, ... }  (sender_id guaranteed)
  static Map<String, dynamic> _flattenSender(Map<String, dynamic> data) {
    final sender = data['sender'];
    if (sender is! Map) return data;

    final flat = Map<String, dynamic>.from(data);
    // Only copy sender_id if it isn't already present at the top level.
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
    final updated = Set<int>.from(current.typingUserIds)..remove(userId);
    emit(current.copyWith(typingUserIds: updated));
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  @override
  Future<void> close() async {
    log('🔴 [ChatCubit] close() called — cleaning up');
    _typingDebounce?.cancel();
    _typingTimeoutTimer?.cancel();
    await _newMessageSub?.cancel();
    await _typingStartSub?.cancel();
    await _typingStopSub?.cancel();
    return super.close();
  }
}