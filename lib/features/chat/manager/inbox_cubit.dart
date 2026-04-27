import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    } catch (e) {
      emit(InboxError(_friendlyError(e)));
    }
  }

  // ─── Upsert a single chat (used after create/open) ────────────────────────

  void upsertChat(ChatModel chat) {
    if (state is InboxLoaded) {
      emit((state as InboxLoaded).upsertChat(chat));
    }
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

      final chatId = data['chat_id'] as int?;
      if (chatId == null) return;

      // Build a minimal MessageModel from the incoming data.
      final msg = MessageModel.fromJson(data, currentUserId: currentUserId);

      final current = state as InboxLoaded;
      final existingChat =
          current.chats.cast<ChatModel?>().firstWhere(
                (c) => c?.id == chatId,
                orElse: () => null,
              );

      if (existingChat == null) {
        // Unknown chat — refresh the full list.
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
