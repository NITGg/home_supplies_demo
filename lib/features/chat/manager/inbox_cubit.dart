//courier

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../data/models/chat_model.dart';
import '../data/models/message_model.dart';
import '../data/repo/chat_repository.dart';
import 'inbox_state.dart';

/// Manages the Inbox screen: chat list, unread badges, and last messages.
///
/// This cubit should live as long as the app is running (typically provided
/// at the top of the widget tree after login) so that it can react to
/// [chat:new_message] events even when the user is not inside a chat screen.
class InboxCubit extends Cubit<InboxState> {
  final ChatRepository _repo;
  final int currentUserId;

  /// The chat that the user currently has open (null if none).
  /// InboxCubit watches this so it does NOT increment unread for the active chat.
  int? _activeChatId;

  StreamSubscription<Map<String, dynamic>>? _newMessageSub;

  InboxCubit({
    required ChatRepository repo,
    required this.currentUserId,
  })  : _repo = repo,
        super(const InboxInitial());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed.
  @override
  void emit(InboxState state) {
    if (!isClosed) super.emit(state);
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> init() async {
    await loadChats();
    _listenToGlobalMessages();
  }

  void setActiveChat(int? chatId) {
    _activeChatId = chatId;
    if (chatId != null && state is InboxLoaded) {
      emit((state as InboxLoaded).clearUnread(chatId));
    }
  }

  // ─── Load Inbox ───────────────────────────────────────────────────────────

  Future<void> loadChats() async {
    emit(const InboxLoading());
    try {
      final chats = await _repo.getMyChats();
      emit(InboxLoaded(chats));
      // Join every known chat room so we receive real-time events
      // even before the user opens a chat screen.
      for (final chat in chats) {
        _repo.joinChat(chat.id);
        dLog('🔗 [InboxCubit] Joined room for chat ${chat.id}');
      }
    } catch (e) {
      emit(InboxError(_friendlyError(e)));
    }
  }

  // ─── Upsert a single chat (used after create/open) ────────────────────────

  void upsertChat(ChatModel chat) {
    if (state is InboxLoaded) {
      emit((state as InboxLoaded).upsertChat(chat));
    }
    // Make sure we're in the room for any newly created chat.
    _repo.joinChat(chat.id);
  }

  // ─── Mark a chat as closed ────────────────────────────────────────────────

  void closeChat(int chatId) {
    if (state is! InboxLoaded) return;
    final updated = (state as InboxLoaded).chats.map((c) {
      return c.id == chatId ? c.copyWith(isClosed: true) : c;
    }).toList();
    emit(InboxLoaded(updated));
  }

  // ─── Global new-message listener (updates last message + unread count) ────

  void _listenToGlobalMessages() {
    _newMessageSub = _repo.onNewMessage.listen((data) {
      if (state is! InboxLoaded) return;

      // The socket fires: { message: { id, chat_id, sender: { id, ... }, ... } }
      // Unwrap the outer "message" envelope if present.
      final msgData = (data['message'] as Map<String, dynamic>?) ?? data;

      // Resolve chat_id — may be int or String from some backends.
      final rawChatId = msgData['chat_id'];
      final chatId = rawChatId is int
          ? rawChatId
          : int.tryParse(rawChatId?.toString() ?? '');

      if (chatId == null) {
        dLog('⚠️ [InboxCubit] new_message missing chat_id — raw: $data');
        return;
      }

      // Normalise sender_id: the socket payload nests sender info under
      // "sender" instead of the flat "sender_id" that MessageModel expects.
      final Map<String, dynamic> normalised = {
        ...msgData,
        if (msgData['sender_id'] == null && msgData['sender'] is Map)
          'sender_id': (msgData['sender'] as Map<String, dynamic>)['id'],
      };

      dLog('💬 [InboxCubit] new_message chatId=$chatId normalised=$normalised');

      final msg = MessageModel.fromJson(normalised, currentUserId: currentUserId);

      final current = state as InboxLoaded;
      final existingChat = current.chats.cast<ChatModel?>().firstWhere(
            (c) => c?.id == chatId,
        orElse: () => null,
      );

      if (existingChat == null) {
        // Unknown chat — join its room and refresh the full list.
        _repo.joinChat(chatId);
        loadChats();
        return;
      }

      // Update last message.
      final updatedChat = existingChat.copyWith(lastMessage: msg);
      InboxLoaded next = current.upsertChat(updatedChat);

      // Increment unread only if the user is NOT currently viewing that chat.
      if (_activeChatId != chatId) {
        next = next.incrementUnread(chatId);
      }

      emit(next);
    });
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  @override
  Future<void> close() async {
    await _newMessageSub?.cancel();
    return super.close();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    // DioException messages are already localised by ApiClient.
    return e.toString();
  }
}