import 'dart:async';

import '../../config/chat_socket_service.dart';
import '../data_source/chat_remote_datasource.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remote;
  final ChatSocketService _socket;

  const ChatRepositoryImpl({
    required ChatRemoteDataSource remote,
    required ChatSocketService socket,
  })  : _remote = remote,
        _socket = socket;

  // ─── HTTP ────────────────────────────────────────────────────────────────

  @override
  Future<List<ChatModel>> getMyChats() => _remote.getMyChats();

  @override
  Future<ChatWithMessagesModel> openChat(int chatId, {ChatModel? knownChat}) =>
      _remote.getChatById(chatId, knownChat: knownChat);

  @override
  Future<({ChatModel chat, bool created})> createOrGetChat(int userId) =>
      _remote.createOrGetChat(userId);

  @override
  Future<List<MessageModel>> loadMoreMessages(
      int chatId, {
        required int page,
      }) =>
      _remote.getMoreMessages(chatId, page: page);

  // ─── Socket: Rooms ────────────────────────────────────────────────────────

  @override
  void joinChat(int chatId) => _socket.joinChat(chatId);

  @override
  void leaveChat(int chatId) => _socket.leaveChat(chatId);

  // ─── HTTP: Messaging ─────────────────────────────────────────────────────

  @override
  Future<MessageModel> sendMessage({
    required int chatId,
    required String content,
    required String type,
  }) =>
      _remote.sendMessage(chatId: chatId, content: content, type: type);

  @override
  void markRead(int chatId) => _socket.markRead(chatId);

  // ─── Socket: Typing ───────────────────────────────────────────────────────

  @override
  void emitTyping(int chatId) => _socket.emitTyping(chatId);

  @override
  void emitStopTyping(int chatId) => _socket.emitStopTyping(chatId);

  // ─── Socket: Streams ──────────────────────────────────────────────────────

  @override
  Stream<Map<String, dynamic>> get onNewMessage => _socket.onNewMessage;

  @override
  Stream<Map<String, dynamic>> get onUserTyping => _socket.onUserTyping;

  @override
  Stream<Map<String, dynamic>> get onUserStoppedTyping =>
      _socket.onUserStoppedTyping;

  @override
  Stream<bool> get onConnectionStatus => _socket.onConnectionStatus;
}