import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../../core/utils/logger.dart';
import '../../../core/utils/socket_service.dart';

/// Handles all chat-specific socket events and room management.
///
/// This service always borrows the live [IO.Socket] from [SocketService].
/// It never opens its own connection — the app already has one shared socket
/// that handles all real-time features (orders, offers, and chat).
///
/// ── Lifecycle ──────────────────────────────────────────────────────────────
///
/// 1. Call [attach] once after [SocketService.connect] has been called
///    (i.e. when the user logs in and the socket is live).
///
/// 2. Use [joinChat] / [leaveChat] / [emitTyping] etc. as normal.
///
/// 3. Call [detach] when the chat feature is torn down (logout, order ends).
///    This removes only the chat listeners — order/offer listeners on the
///    shared socket are completely unaffected.
///
/// ── Pending-room buffering ──────────────────────────────────────────────────
///
/// [attach] may be called before the socket handshake completes (the socket
/// object exists but [IO.Socket.connected] is still false).  Any [joinChat]
/// call made while the socket is not yet connected is buffered in
/// [_pendingRooms] and replayed automatically once the `connect` event fires.
class ChatSocketService {
  static final ChatSocketService _instance = ChatSocketService._internal();

  factory ChatSocketService() => _instance;

  ChatSocketService._internal();

  // The borrowed socket reference — set by [attach], cleared by [detach].
  IO.Socket? _socket;

  // Rooms that were requested before the socket finished connecting.
  // Drained inside the onConnect handler registered in [attach].
  final Set<int> _pendingRooms = {};

  // ─── Stream Controllers ────────────────────────────────────────────────────
  // Broadcast streams — never closed; the singleton may be re-attached many
  // times per session (e.g. user enters and leaves chat multiple times).
  final _newMessageController =
  StreamController<Map<String, dynamic>>.broadcast();
  final _userTypingController =
  StreamController<Map<String, dynamic>>.broadcast();
  final _userStoppedTypingController =
  StreamController<Map<String, dynamic>>.broadcast();

  final _messageReadController =
  StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  // ─── Active Chat Rooms ─────────────────────────────────────────────────────
  final Set<int> _activeChatRooms = {};

  // ─── Public Streams ────────────────────────────────────────────────────────
  Stream<Map<String, dynamic>> get onMessageRead => _messageReadController.stream;

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;
  Stream<Map<String, dynamic>> get onUserStoppedTyping =>
      _userStoppedTypingController.stream;
  Stream<bool> get onConnectionStatus => _connectionStatusController.stream;

  bool get isConnected => SocketService().isConnected;
  Set<int> get activeChatRooms => Set.unmodifiable(_activeChatRooms);

  // ─── ATTACH ────────────────────────────────────────────────────────────────

  /// Borrows the live socket from [SocketService] and registers chat-specific
  /// event listeners on it.
  ///
  /// Safe to call multiple times — if already attached it is a no-op.
  /// Must be called after [SocketService.connect].
  ///
  /// If the socket is not yet connected when [attach] is called, a one-time
  /// `connect` listener is registered to drain [_pendingRooms] as soon as
  /// the handshake completes.
  void attach() {
    if (_socket != null) {
      dLog('🔗 [ChatSocket] Already attached — skipping');
      return;
    }

    final socket = SocketService().rawSocket;
    if (socket == null) {
      dLog('🚨 [ChatSocket] attach() called before SocketService.connect() — '
          'chat socket events will not work. Call ChatModule.init() after '
          'the main socket is connected.');
      return;
    }

    _socket = socket;
    _registerChatListeners();
    _connectionStatusController.add(socket.connected);

    if (socket.connected) {
      dLog('🔗 [ChatSocket] Attached to SocketService socket (id: ${socket.id}, '
          'connected: true)');
      _drainPendingRooms();
    } else {
      // Socket exists but hasn't finished the handshake yet (id is null).
      // Register a one-shot connect callback to drain pending rooms.
      dLog('🔗 [ChatSocket] Attached to SocketService socket — '
          'not yet connected, will join pending rooms on connect');

      void onConnect(_) {
        dLog('🔗 [ChatSocket] Socket connected (id: ${_socket?.id}) — '
            'draining ${_pendingRooms.length} pending room(s)');
        _connectionStatusController.add(true);
        _drainPendingRooms();
        // Remove this one-shot listener so it doesn't fire again on reconnect.
        _socket?.off('connect', onConnect);
      }

      socket.on('connect', onConnect);
    }
  }

  // ─── DETACH ────────────────────────────────────────────────────────────────

  /// Leaves all active chat rooms, removes chat listeners, and releases the
  /// borrowed socket reference.
  ///
  /// The shared socket itself is left completely untouched — order/offer
  /// listeners registered by [SocketService] continue to work normally.
  void detach() {
    if (_socket == null) return;

    // Leave every room we joined.
    for (final chatId in Set<int>.from(_activeChatRooms)) {
      _socket!.emit('chat:leave', {'chatId': chatId});
      dLog('🔓 [ChatSocket] Left chat room $chatId (detach)');
    }
    _activeChatRooms.clear();
    _pendingRooms.clear();

    // Remove ONLY the chat listeners — do NOT call socket.off() globally,
    // as that would remove the order/offer listeners too.
    _socket!.off('chat:new_message');
    _socket!.off('chat:user_typing');
    _socket!.off('chat:user_stopped_typing');
    _socket!.off('chat:message_read');

    _socket = null;
    dLog('🔓 [ChatSocket] Detached from SocketService socket');
  }

  // ─── EVENT LISTENERS ──────────────────────────────────────────────────────

  void _registerChatListeners() {
    _socket!.on('chat:new_message', (data) {
      dLog('💬 [ChatSocket] chat:new_message → $data');
      final map = _toMap(data);
      if (map != null) _newMessageController.add(map);
    });

    _socket!.on('chat:user_typing', (data) {
      dLog('✏️  [ChatSocket] chat:user_typing → $data');
      final map = _toMap(data);
      if (map != null) _userTypingController.add(map);
    });


    _socket!.on('chat:message_read', (data) {
      dLog('✅ [ChatSocket] chat:message_read → $data');
      final map = _toMap(data);
      if (map != null) _messageReadController.add(map);
    });

    _socket!.on('chat:user_stopped_typing', (data) {
      dLog('⏹️  [ChatSocket] chat:user_stopped_typing → $data');
      final map = _toMap(data);
      if (map != null) _userStoppedTypingController.add(map);
    });
  }

  // ─── ROOM MANAGEMENT ──────────────────────────────────────────────────────

  /// Joins a chat room.
  ///
  /// If the socket is not yet connected (possible when [attach] is called
  /// early), the room is buffered in [_pendingRooms] and joined automatically
  /// once the `connect` event fires.
  void joinChat(int chatId) {
    if (_activeChatRooms.contains(chatId)) return;

    if (!isConnected) {
      // Socket isn't ready yet — buffer and replay on connect.
      _pendingRooms.add(chatId);
      dLog('⏳ [ChatSocket] Socket not connected — buffering join for chat $chatId');
      return;
    }

    _socket!.emit('chat:join', {'chatId': chatId});
    _activeChatRooms.add(chatId);
    dLog('🔗 [ChatSocket] Joined chat room: $chatId');
  }

  void leaveChat(int chatId) {
    _pendingRooms.remove(chatId);
    if (!_activeChatRooms.contains(chatId)) return;

    _socket?.emit('chat:leave', {'chatId': chatId});
    _activeChatRooms.remove(chatId);
    dLog('🔓 [ChatSocket] Left chat room: $chatId');
  }

  /// Drains [_pendingRooms] by emitting `chat:join` for each room.
  /// Called once the socket signals `connect`.
  void _drainPendingRooms() {
    if (_pendingRooms.isEmpty) return;
    final toJoin = Set<int>.from(_pendingRooms);
    _pendingRooms.clear();
    for (final chatId in toJoin) {
      if (_activeChatRooms.contains(chatId)) continue;
      _socket!.emit('chat:join', {'chatId': chatId});
      _activeChatRooms.add(chatId);
      dLog('🔗 [ChatSocket] Joined pending chat room: $chatId');
    }
  }

  // ─── TYPING ───────────────────────────────────────────────────────────────

  void emitTyping(int chatId) {
    _socket?.emit('chat:typing', {'chatId': chatId});
  }

  void emitStopTyping(int chatId) {
    _socket?.emit('chat:stop_typing', {'chatId': chatId});
  }

  // ─── READ RECEIPTS ────────────────────────────────────────────────────────

  void markRead(int chatId) {
    _socket?.emit('chat:read_messages', {'chatId': chatId});
    dLog('👁️  [ChatSocket] Marked chat $chatId as read');
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Map<String, dynamic>? _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }
}