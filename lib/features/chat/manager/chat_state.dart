//courier

import 'package:equatable/equatable.dart';

import '../data/models/chat_model.dart';
import '../data/models/message_model.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

// ─── Initial / Loading ────────────────────────────────────────────────────────

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

// ─── Main loaded state ────────────────────────────────────────────────────────

/// The primary state while the user is inside a chat screen.
///
/// All sub-transitions (new message, typing, pagination) emit a copy of this
/// state rather than introducing extra state classes — this prevents the UI
/// from flickering between a "loaded" root and nested states.
class ChatLoaded extends ChatState {
  final ChatModel chat;
  final List<MessageModel> messages;

  /// True while loading older messages (pagination).
  final bool isLoadingMore;

  /// False when all history pages have been fetched.
  final bool hasMore;
  final int nextPage;

  /// IDs of users currently typing (excludes self).
  final Set<int> typingUserIds;

  /// True after the associated order is confirmed/completed.
  final bool isClosed;

  const ChatLoaded({
    required this.chat,
    required this.messages,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.nextPage = 2,
    this.typingUserIds = const {},
    this.isClosed = false,
  });

  ChatLoaded copyWith({
    ChatModel? chat,
    List<MessageModel>? messages,
    bool? isLoadingMore,
    bool? hasMore,
    int? nextPage,
    Set<int>? typingUserIds,
    bool? isClosed,
  }) {
    return ChatLoaded(
      chat: chat ?? this.chat,
      messages: messages ?? this.messages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      isClosed: isClosed ?? this.isClosed,
    );
  }

  @override
  List<Object?> get props => [
    chat,
    messages,
    isLoadingMore,
    hasMore,
    nextPage,
    typingUserIds,
    isClosed,
  ];
}

// ─── Error states ─────────────────────────────────────────────────────────────

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Emitted when the server responds with 403 to a chat action (e.g.
/// sending a message), which means the underlying order has ended and the
/// chat is no longer accessible. The UI should show a message and close the
/// chat screen.
class ChatOrderEnded extends ChatState {
  const ChatOrderEnded();
}

/// Emitted when a single message fails to send.
/// Does NOT replace [ChatLoaded] — the UI shows a snackbar / retry prompt
/// while the message list remains visible.
class MessageSendFailed extends ChatState {
  final ChatLoaded currentState;
  final String failedMessageLocalId;
  final String error;

  const MessageSendFailed({
    required this.currentState,
    required this.failedMessageLocalId,
    required this.error,
  });

  @override
  List<Object?> get props => [currentState, failedMessageLocalId, error];
}
