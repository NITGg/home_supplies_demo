import 'dart:developer';

import 'package:dio/dio.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

// ─── Base URL ─────────────────────────────────────────────────────────────────
const _kChatBase =
    'https://tawreedat.nitg-eg.com/courier_apis/api/v1/courier/chat';

abstract class ChatRemoteDataSource {
  Future<List<ChatModel>> getMyChats();

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

  /// Uploads [filePath] as a multipart form-data image message.
  Future<MessageModel> sendImageMessage({
    required int chatId,
    required String filePath,
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
    log('📡 [ChatDS] GET $_kChatBase/get-my-chats');
    final response = await _dio.get('$_kChatBase/get-my-chats');
    log('📡 [ChatDS] getMyChats raw response: ${response.data}');

    final extracted = _extractData(response.data);

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
    final chatJson = (data['chat'] as Map<String, dynamic>?) ?? data;
    final created = data['created'] as bool? ?? false;

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

    final extracted = _extractData(response.data) as Map<String, dynamic>;
    final wrapped = ChatWithMessagesModel.fromJson(
      extracted,
      currentUserId: currentUserId,
      currentPage: page,
    );
    return wrapped.messages;
  }

  @override
  Future<MessageModel> sendMessage({
    required int chatId,
    required String content,
    required String type,
  }) async {
    log('📡 [ChatDS] POST $_kChatBase/send-message/$chatId (text)');
    final response = await _dio.post(
      '$_kChatBase/send-message/$chatId',
      data: {'content': content, 'type': type},
    );
    log('📡 [ChatDS] sendMessage($chatId) raw response: ${response.data}');

    final raw = _extractData(response.data);
    final msgJson = raw is Map<String, dynamic>
        ? ((raw['message'] as Map<String, dynamic>?) ?? raw)
        : raw as Map<String, dynamic>;

    return MessageModel.fromJson(msgJson, currentUserId: currentUserId);
  }

  @override
  Future<MessageModel> sendImageMessage({
    required int chatId,
    required String filePath,
  }) async {
    log('📡 [ChatDS] POST $_kChatBase/send-message/$chatId (image)');

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'type': 'IMAGE',
    });

    final response = await _dio.post(
      '$_kChatBase/send-message/$chatId',
      data: formData,
      options: Options(
        // Let Dio set Content-Type with the boundary automatically.
        contentType: 'multipart/form-data',
      ),
    );
    log('📡 [ChatDS] sendImageMessage($chatId) raw response: ${response.data}');

    final raw = _extractData(response.data);
    final msgJson = raw is Map<String, dynamic>
        ? ((raw['message'] as Map<String, dynamic>?) ?? raw)
        : raw as Map<String, dynamic>;

    return MessageModel.fromJson(msgJson, currentUserId: currentUserId);
  }

  dynamic _extractData(dynamic responseData) {
    if (responseData is Map<String, dynamic> &&
        responseData.containsKey('data')) {
      return responseData['data'];
    }
    return responseData;
  }
}