import 'dart:async';
import '../../data/models/chat_model.dart';
import '../../data/models/message_model.dart';

/// Domain contract for the Chat feature.
abstract class ChatRepository {
  // ─── HTTP ────────────────────────────────────────────────────────────────

  Future<List<ChatModel>> getMyChats();

  Future<ChatWithMessagesModel> openChat(int chatId, {ChatModel? knownChat});

  Future<({ChatModel chat, bool created})> createOrGetChat(int userId);

  Future<List<MessageModel>> loadMoreMessages(int chatId, {required int page});

  // ─── Socket: Rooms ────────────────────────────────────────────────────────

  void joinChat(int chatId);

  void leaveChat(int chatId);

  // ─── Messaging ────────────────────────────────────────────────────────────

  Future<MessageModel> sendMessage({
    required int chatId,
    required String content,
    required String type,
  });

  /// Sends an image message using multipart form-data.
  /// [filePath] is the absolute path to the image file on disk.
  Future<MessageModel> sendImageMessage({
    required int chatId,
    required String filePath,
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