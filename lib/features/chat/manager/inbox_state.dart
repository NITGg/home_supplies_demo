//courier
import 'package:equatable/equatable.dart';

import '../data/models/chat_model.dart';

abstract class InboxState extends Equatable {
  const InboxState();

  @override
  List<Object?> get props => [];
}

class InboxInitial extends InboxState {
  const InboxInitial();
}

class InboxLoading extends InboxState {
  const InboxLoading();
}

class InboxLoaded extends InboxState {
  final List<ChatModel> chats;

  const InboxLoaded(this.chats);

  /// Sum of unread counts across all chats.
  int get totalUnreadCount =>
      chats.fold(0, (sum, c) => sum + c.unreadCount);

  /// Returns a new [InboxLoaded] with [chat] inserted or updated in-place.
  InboxLoaded upsertChat(ChatModel chat) {
    final index = chats.indexWhere((c) => c.id == chat.id);
    final updated = List<ChatModel>.from(chats);
    if (index >= 0) {
      updated[index] = chat;
    } else {
      updated.insert(0, chat);
    }
    // Keep sorted: most recently updated first.
    updated.sort((a, b) {
      final aTime = a.lastMessage?.createdAt ?? a.updatedAt ?? DateTime(0);
      final bTime = b.lastMessage?.createdAt ?? b.updatedAt ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return InboxLoaded(updated);
  }

  /// Increments unread count for a specific chat.
  InboxLoaded incrementUnread(int chatId) {
    return InboxLoaded(
      chats.map((c) {
        if (c.id != chatId) return c;
        return c.copyWith(unreadCount: c.unreadCount + 1);
      }).toList(),
    );
  }

  /// Resets unread count for a specific chat (user opened it).
  InboxLoaded clearUnread(int chatId) {
    return InboxLoaded(
      chats.map((c) => c.id == chatId ? c.copyWith(unreadCount: 0) : c).toList(),
    );
  }

  @override
  List<Object?> get props => [chats];
}

class InboxError extends InboxState {
  final String message;

  const InboxError(this.message);

  @override
  List<Object?> get props => [message];
}