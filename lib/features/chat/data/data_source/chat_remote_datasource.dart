import 'dart:developer';

import 'package:dio/dio.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

// ─── Base URL ─────────────────────────────────────────────────────────────────
const _kChatBase =
    'https://tawreedat.nitg-eg.com/courier_apis/api/v1/courier/chat';

abstract class ChatRemoteDataSource {
  Future<List<ChatModel>> getMyChats();

  /// Pass [knownChat] when you already have the chat metadata so the
  /// messages-only response shape can be handled without losing the chat id.
  Future<ChatWithMessagesModel> getChatById(
      int chatId, {
        int page = 1,
        ChatModel? knownChat,
      });

  Future<({ChatModel chat, bool created})> createOrGetChat(int userId);

  Future<List<MessageModel>> getMoreMessages(int chatId, {required int page});

  Future<MessageModel> sendMessage({
    required int chatId,
    required String content,
    required String type,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final Dio _dio;
  final int currentUserId;

  const ChatRemoteDataSourceImpl({
    required Dio dio,
    required this.currentUserId,
  }) : _dio = dio;

  @override
  Future<List<ChatModel>> getMyChats() async {
    log('📡 [ChatDS] GET $_kChatBase/get-my-chats&includes=participants,messages');
    final response = await _dio.get('$_kChatBase/get-my-chats');
    log('📡 [ChatDS] getMyChats raw response: ${response.data}');

    final extracted = _extractData(response.data);

    // Server wraps the list under "myChats" inside the data envelope.
    final raw = extracted is Map<String, dynamic>
        ? (extracted['myChats'] as List<dynamic>? ?? [])
        : extracted is List
        ? extracted
        : <dynamic>[];

    log('📡 [ChatDS] getMyChats list length: ${raw.length}');
    return raw
        .map((e) => ChatModel.fromJson(
      e as Map<String, dynamic>,
      currentUserId: currentUserId,
    ))
        .toList();
  }

  @override
  Future<ChatWithMessagesModel> getChatById(
      int chatId, {
        int page = 1,
        ChatModel? knownChat,
      }) async {
    log('📡 [ChatDS] GET $_kChatBase/get-chat/$chatId?page=$page');
    final response = await _dio.get(
      '$_kChatBase/get-chat/$chatId',
      queryParameters: {'page': page, 'limit': 30},
    );
    log('📡 [ChatDS] getChatById($chatId) raw response: ${response.data}');

    final extracted = _extractData(response.data) as Map<String, dynamic>;
    log('📡 [ChatDS] getChatById($chatId) extracted: $extracted');

    return ChatWithMessagesModel.fromJson(
      extracted,
      currentUserId: currentUserId,
      knownChat: knownChat,
    );
  }

  @override
  Future<({ChatModel chat, bool created})> createOrGetChat(int userId) async {
    log('📡 [ChatDS] POST $_kChatBase/create-chat/$userId');
    final response = await _dio.post('$_kChatBase/create-chat/$userId');
    log('📡 [ChatDS] createOrGetChat($userId) raw response: ${response.data}');

    final data = _extractData(response.data) as Map<String, dynamic>;
    log('📡 [ChatDS] createOrGetChat($userId) extracted map: $data');

    final chatJson = (data['chat'] as Map<String, dynamic>?) ?? data;
    final created = data['created'] as bool? ?? false;

    log('📡 [ChatDS] createOrGetChat — id: ${chatJson['id']}, '
        'is_closed: ${chatJson['is_closed']}, created: $created');

    return (
    chat: ChatModel.fromJson(chatJson, currentUserId: currentUserId),
    created: created,
    );
  }

  @override
  Future<List<MessageModel>> getMoreMessages(
      int chatId, {
        required int page,
      }) async {
    log('📡 [ChatDS] GET $_kChatBase/get-chat/$chatId?page=$page (loadMore)');
    final response = await _dio.get(
      '$_kChatBase/get-chat/$chatId',
      queryParameters: {'page': page, 'limit': 30},
    );
    log('📡 [ChatDS] getMoreMessages($chatId, page=$page) raw: ${response.data}');

    final extracted = _extractData(response.data) as Map<String, dynamic>;
    final wrapped = ChatWithMessagesModel.fromJson(
      extracted,
      currentUserId: currentUserId,
      currentPage: page,
    );
    log('📡 [ChatDS] getMoreMessages($chatId) parsed ${wrapped.messages.length} messages');
    return wrapped.messages;
  }

  @override
  Future<MessageModel> sendMessage({
    required int chatId,
    required String content,
    required String type,
  }) async {
    log('📡 [ChatDS] POST $_kChatBase/send-message/$chatId');
    final response = await _dio.post(
      '$_kChatBase/send-message/$chatId',
      data: {'content': content, 'type': type},
    );
    log('📡 [ChatDS] sendMessage($chatId) raw response: ${response.data}');

    final raw = _extractData(response.data);
    final msgJson = raw is Map<String, dynamic>
        ? ((raw['message'] as Map<String, dynamic>?) ?? raw)
        : raw as Map<String, dynamic>;

    log('📡 [ChatDS] sendMessage($chatId) parsed msgJson: $msgJson');
    return MessageModel.fromJson(msgJson, currentUserId: currentUserId);
  }

  dynamic _extractData(dynamic responseData) {
    log('📡 [ChatDS] _extractData input type: ${responseData.runtimeType}');
    if (responseData is Map<String, dynamic> &&
        responseData.containsKey('data')) {
      log('📡 [ChatDS] _extractData: unwrapping "data" key');
      return responseData['data'];
    }
    log('📡 [ChatDS] _extractData: returning as-is');
    return responseData;
  }
}