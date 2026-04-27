import 'dart:async';
import '../../data/models/chat_model.dart';
import '../../data/models/message_model.dart';

/// Domain contract for the Chat feature.
///
/// All methods are defined generically — no courier/customer distinction.
/// The repository is the single point of truth; the cubit never touches
/// datasources directly.
abstract class ChatRepository {
  // ─── HTTP ────────────────────────────────────────────────────────────────

  Future<List<ChatModel>> getMyChats();

  /// Fetches the first page of messages for [chatId].
  ///
  /// Pass [knownChat] when the chat metadata is already available (e.g. from
  /// [createOrGetChat]) so the datasource can use it when the server returns
  /// a messages-only response shape with no chat metadata.
  Future<ChatWithMessagesModel> openChat(int chatId, {ChatModel? knownChat});

  Future<({ChatModel chat, bool created})> createOrGetChat(int userId);

  Future<List<MessageModel>> loadMoreMessages(int chatId, {required int page});

  // ─── Socket: Rooms ────────────────────────────────────────────────────────

  void joinChat(int chatId);

  void leaveChat(int chatId);

  // ─── Socket: Messaging ────────────────────────────────────────────────────

  /// Sends a message via HTTP and returns the server-persisted [MessageModel].
  Future<MessageModel> sendMessage({
    required int chatId,
    required String content,
    required String type,
  });

  void markRead(int chatId);

  // ─── Socket: Typing ───────────────────────────────────────────────────────

  void emitTyping(int chatId);

  void emitStopTyping(int chatId);

  // ─── Socket: Streams ──────────────────────────────────────────────────────

  Stream<Map<String, dynamic>> get onNewMessage;

  Stream<Map<String, dynamic>> get onUserTyping;

  Stream<Map<String, dynamic>> get onUserStoppedTyping;

  Stream<bool> get onConnectionStatus;
}