// client — chat_socket_service.dart
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../../core/utils/logger.dart';
import '../../../core/utils/socket_service.dart';

/// Handles all chat-specific socket events and room management.
///
/// This service always borrows the live [IO.Socket] from [SocketService].
/// It never opens its own connection.
///
/// ── Lifecycle ──────────────────────────────────────────────────────────────
///
/// 1. Call [attach] once after [SocketService.connect] has been called.
///    If the socket isn't ready yet, [attach] schedules a self-healing retry
///    that fires as soon as [SocketService.rawSocket] becomes available.
///
/// 2. Use [joinChat] / [leaveChat] / [emitTyping] etc. as normal.
///
/// 3. Call [detach] on logout or when the chat feature is torn down.
///    Order/offer listeners on the shared socket are completely unaffected.
///
/// ── Self-healing attach ────────────────────────────────────────────────────
///
/// If [attach] is called before [SocketService] has a live socket, it sets a
/// flag and polls every 500 ms until [rawSocket] is non-null, then completes
/// the attach automatically.  Any [joinChat] calls made during this window are
/// buffered in [_pendingRooms] and drained once the socket is ready.
///
/// ── Reconnect handling ─────────────────────────────────────────────────────
///
/// A persistent `connect` listener re-joins [_activeChatRooms] on every
/// reconnect so the server always has an up-to-date membership for this client.
///
/// ── Stale-socket detection ─────────────────────────────────────────────────
///
/// [attach] compares its stored [_socket] reference to [SocketService.rawSocket]
/// on every call. If they differ (e.g. the shared socket was reconnected with a
/// new instance), the old listeners are removed and the service re-attaches to
/// the fresh socket automatically.
class ChatSocketService {
  static final ChatSocketService _instance = ChatSocketService._internal();

  factory ChatSocketService() => _instance;

  ChatSocketService._internal();

  IO.Socket? _socket;

  // Self-healing: true while we're waiting for rawSocket to become available.
  bool _pendingAttach = false;
  Timer? _attachRetryTimer;

  // Rooms requested before the socket finished connecting.
  final Set<int> _pendingRooms = {};

  // ─── Stream Controllers ────────────────────────────────────────────────────
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
  // NOT cleared on disconnect — preserved so we can re-join on reconnect.
  final Set<int> _activeChatRooms = {};

  // ─── Public Streams ────────────────────────────────────────────────────────
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;
  Stream<Map<String, dynamic>> get onUserStoppedTyping =>
      _userStoppedTypingController.stream;
  Stream<Map<String, dynamic>> get onMessageRead =>
      _messageReadController.stream;
  Stream<bool> get onConnectionStatus => _connectionStatusController.stream;

  bool get isConnected => SocketService().isConnected;

  /// True only when the socket is actually borrowed and listeners are active.
  bool get isAttached => _socket != null;

  Set<int> get activeChatRooms => Set.unmodifiable(_activeChatRooms);

  // ─── ATTACH ────────────────────────────────────────────────────────────────

  /// Borrows the live socket from [SocketService] and registers chat-specific
  /// event listeners on it.
  ///
  /// Safe to call on every [ChatScreen] open:
  /// - If already attached to the **same** socket instance → no-op.
  /// - If the shared socket was replaced (e.g. after a full reconnect) →
  ///   removes stale listeners and re-attaches to the fresh instance.
  /// - If [SocketService.rawSocket] is null → schedules a 500 ms retry loop
  ///   until the socket is available (self-healing attach).
  void attach() {
    final currentSocket = SocketService().rawSocket;

    dLog(
      '🔗 [ChatSocket][CLIENT] attach() called — '
          'storedSocket=${_socket != null ? "exists" : "null"}, '
          'currentSocket=${currentSocket != null ? "exists" : "null"}, '
          'sameInstance=${_socket != null && _socket == currentSocket}, '
          'pendingAttach=$_pendingAttach, '
          'SocketService.isConnected=${SocketService().isConnected}',
    );

    // ── Already attached to the current socket instance — nothing to do. ──
    if (_socket != null && _socket == currentSocket) {
      dLog('🔗 [ChatSocket][CLIENT] Already attached to current socket — skipping');
      return;
    }

    // ── Stale reference: SocketService gave us a new socket object. ──────────
    // Remove old listeners before re-attaching to the fresh instance.
    if (_socket != null && _socket != currentSocket) {
      dLog(
        '⚠️ [ChatSocket][CLIENT] Socket reference changed — '
            'detaching stale listeners before re-attaching',
      );
      _detachListeners();
      _socket = null;
    }

    // ── Socket not yet available — schedule self-healing retry. ──────────────
    if (currentSocket == null) {
      if (_pendingAttach) {
        dLog(
          '⏳ [ChatSocket][CLIENT] attach() — rawSocket still null, '
              'retry already scheduled',
        );
        return;
      }
      dLog(
        '⏳ [ChatSocket][CLIENT] attach() — rawSocket is null. '
            'Scheduling self-healing retry every 500 ms…',
      );
      _pendingAttach = true;
      _scheduleAttachRetry();
      return;
    }

    // ── Socket is available — complete the attach synchronously. ─────────────
    _pendingAttach = false;
    _attachRetryTimer?.cancel();
    _attachRetryTimer = null;

    _completeAttach(currentSocket);
  }

  // ─── DETACH LISTENERS (stale-socket cleanup) ──────────────────────────────

  /// Removes all chat-specific event listeners from [_socket] without leaving
  /// rooms or nulling the reference — used when the socket instance changes.
  ///
  /// Note: [socket_io_client] removes **all** handlers for a given event name
  /// when [off] is called without a specific callback, so this will also remove
  /// the `connect` / `disconnect` handlers registered by [_completeAttach].
  /// That is intentional here — [_completeAttach] will re-register them on the
  /// fresh socket.
  void _detachListeners() {
    if (_socket == null) return;
    dLog(
      '🔓 [ChatSocket][CLIENT] _detachListeners — '
          'removing listeners from stale socket (id=${_socket!.id})',
    );
    _socket!.off('connect');
    _socket!.off('disconnect');
    _socket!.off('chat:new_message');
    _socket!.off('chat:user_typing');
    _socket!.off('chat:user_stopped_typing');
    _socket!.off('chat:message_read');
  }

  void _scheduleAttachRetry() {
    _attachRetryTimer?.cancel();
    _attachRetryTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final socket = SocketService().rawSocket;
      if (socket == null) {
        dLog(
          '⏳ [ChatSocket][CLIENT] Retry: rawSocket still null — waiting…',
        );
        return;
      }
      dLog(
        '✅ [ChatSocket][CLIENT] Retry: rawSocket now available '
            '(connected=${socket.connected}) — completing attach',
      );
      _attachRetryTimer?.cancel();
      _attachRetryTimer = null;
      _pendingAttach = false;
      _completeAttach(socket);
    });
  }

  void _completeAttach(IO.Socket socket) {
    _socket = socket;
    _registerChatListeners();

    // ── Persistent reconnect handler ──────────────────────────────────────────
    // Fires on EVERY connect/reconnect (not just the first time), so
    // _activeChatRooms are always re-joined after a network blip.
    _socket!.onConnect((_) {
      dLog(
        '✅ [ChatSocket][CLIENT] Socket connected/reconnected — '
            'id=${_socket?.id}, '
            'activeRooms=$_activeChatRooms, '
            'pendingRooms=$_pendingRooms',
      );
      _connectionStatusController.add(true);

      if (_activeChatRooms.isNotEmpty) {
        dLog(
          '🔁 [ChatSocket][CLIENT] Re-joining ${_activeChatRooms.length} '
              'active room(s) after reconnect: $_activeChatRooms',
        );
        for (final chatId in Set<int>.from(_activeChatRooms)) {
          dLog(
            '🔗 [ChatSocket][CLIENT] Re-emitting chat:join for room $chatId',
          );
          _socket!.emit('chat:join', {'chatId': chatId});
        }
      } else {
        dLog('ℹ️  [ChatSocket][CLIENT] No active rooms to re-join on connect');
      }

      // Drain rooms buffered while the socket was still connecting.
      _drainPendingRooms();
    });

    _socket!.onDisconnect((reason) {
      dLog(
        '❌ [ChatSocket][CLIENT] Socket disconnected — reason="$reason", '
            'activeRooms=$_activeChatRooms '
            '(preserved for re-join on next reconnect)',
      );
      _connectionStatusController.add(false);
      // Intentionally NOT clearing _activeChatRooms here.
    });

    _connectionStatusController.add(socket.connected);

    if (socket.connected) {
      dLog(
        '🔗 [ChatSocket][CLIENT] Socket already connected (id=${socket.id}) — '
            'draining ${_pendingRooms.length} pending room(s)',
      );
      _drainPendingRooms();
    } else {
      dLog(
        '🔗 [ChatSocket][CLIENT] Socket not yet fully connected — '
            'rooms will be joined once the connect event fires',
      );
    }

    dLog(
      '✅ [ChatSocket][CLIENT] _completeAttach done — '
          'socketId=${socket.id}, connected=${socket.connected}',
    );
  }

  // ─── DETACH ────────────────────────────────────────────────────────────────

  void detach() {
    dLog(
      '🔓 [ChatSocket][CLIENT] detach() called — '
          'socketAttached=${_socket != null}, '
          'pendingAttach=$_pendingAttach, '
          'activeRooms=$_activeChatRooms, '
          'pendingRooms=$_pendingRooms',
    );

    // Cancel any pending self-healing retry.
    _attachRetryTimer?.cancel();
    _attachRetryTimer = null;
    _pendingAttach = false;

    if (_socket == null) {
      dLog(
        'ℹ️  [ChatSocket][CLIENT] detach() — socket null, just clearing rooms',
      );
      _activeChatRooms.clear();
      _pendingRooms.clear();
      return;
    }

    for (final chatId in Set<int>.from(_activeChatRooms)) {
      dLog('🔓 [ChatSocket][CLIENT] Emitting chat:leave for room $chatId');
      _socket!.emit('chat:leave', {'chatId': chatId});
    }
    _activeChatRooms.clear();
    _pendingRooms.clear();

    // Remove ONLY the chat listeners — do NOT call socket.offAny() globally
    // as that would wipe the order/offer listeners registered by SocketService.
    _detachListeners();

    _socket = null;
    dLog('🔓 [ChatSocket][CLIENT] Detached ✓');
  }

  // ─── EVENT LISTENERS ──────────────────────────────────────────────────────

  void _registerChatListeners() {
    dLog('👂 [ChatSocket][CLIENT] Registering chat event listeners…');

    _socket!.on('chat:new_message', (data) {
      dLog('💬 [ChatSocket][CLIENT] chat:new_message received → $data');
      final map = _toMap(data);
      if (map != null) {
        dLog(
          '💬 [ChatSocket][CLIENT] chat:new_message — pushing to stream, '
              'hasListeners=${_newMessageController.hasListener}',
        );
        _newMessageController.add(map);
      } else {
        dLog(
          '⚠️ [ChatSocket][CLIENT] chat:new_message — could not parse '
              'data (type=${data.runtimeType}): $data',
        );
      }
    });

    _socket!.on('chat:user_typing', (data) {
      dLog('✏️  [ChatSocket][CLIENT] chat:user_typing → $data');
      final map = _toMap(data);
      if (map != null) _userTypingController.add(map);
    });

    _socket!.on('chat:user_stopped_typing', (data) {
      dLog('⏹️  [ChatSocket][CLIENT] chat:user_stopped_typing → $data');
      final map = _toMap(data);
      if (map != null) _userStoppedTypingController.add(map);
    });

    _socket!.on('chat:message_read', (data) {
      dLog('✅ [ChatSocket][CLIENT] chat:message_read → $data');
      final map = _toMap(data);
      if (map != null) _messageReadController.add(map);
    });

    dLog('👂 [ChatSocket][CLIENT] Chat event listeners registered ✓');
  }

  // ─── ROOM MANAGEMENT ──────────────────────────────────────────────────────

  void joinChat(int chatId) {
    dLog(
      '🔗 [ChatSocket][CLIENT] joinChat($chatId) — '
          'isConnected=$isConnected, '
          'isAttached=$isAttached, '
          'alreadyActive=${_activeChatRooms.contains(chatId)}, '
          'activeRooms=$_activeChatRooms, '
          'pendingAttach=$_pendingAttach',
    );

    // Socket not attached yet — buffer the room and trigger self-healing attach.
    if (_socket == null) {
      _pendingRooms.add(chatId);
      _activeChatRooms.add(chatId);
      dLog(
        '⏳ [ChatSocket][CLIENT] joinChat($chatId) — socket not attached, '
            'buffered. pendingRooms=$_pendingRooms. Triggering attach()…',
      );
      if (!_pendingAttach) attach();
      return;
    }

    // Guard: skip duplicate emits when already in the room and connected.
    if (_activeChatRooms.contains(chatId) && isConnected) {
      dLog(
        'ℹ️  [ChatSocket][CLIENT] joinChat($chatId) — already in room and '
            'connected, skipping duplicate emit',
      );
      return;
    }

    if (!isConnected) {
      _pendingRooms.add(chatId);
      _activeChatRooms.add(chatId);
      dLog(
        '⏳ [ChatSocket][CLIENT] joinChat($chatId) — attached but not yet '
            'connected, buffered. pendingRooms=$_pendingRooms',
      );
      return;
    }

    dLog('📤 [ChatSocket][CLIENT] Emitting chat:join for room $chatId');
    _socket!.emit('chat:join', {'chatId': chatId});
    _activeChatRooms.add(chatId);
    dLog(
      '✅ [ChatSocket][CLIENT] Joined room $chatId — '
          'activeRooms=$_activeChatRooms',
    );
  }

  void leaveChat(int chatId) {
    dLog(
      '🔓 [ChatSocket][CLIENT] leaveChat($chatId) — '
          'inActiveRooms=${_activeChatRooms.contains(chatId)}, '
          'inPendingRooms=${_pendingRooms.contains(chatId)}, '
          'isAttached=$isAttached',
    );

    _pendingRooms.remove(chatId);

    if (!_activeChatRooms.contains(chatId)) {
      dLog(
        'ℹ️  [ChatSocket][CLIENT] leaveChat($chatId) — not in active rooms, '
            'skipping emit',
      );
      return;
    }

    if (_socket != null) {
      dLog('📤 [ChatSocket][CLIENT] Emitting chat:leave for room $chatId');
      _socket!.emit('chat:leave', {'chatId': chatId});
    } else {
      dLog(
        '⚠️ [ChatSocket][CLIENT] leaveChat($chatId) — socket null, '
            'removing from active rooms without emit',
      );
    }

    _activeChatRooms.remove(chatId);
    dLog(
      '✅ [ChatSocket][CLIENT] Left room $chatId — '
          'activeRooms=$_activeChatRooms',
    );
  }

  void _drainPendingRooms() {
    if (_pendingRooms.isEmpty) {
      dLog('ℹ️  [ChatSocket][CLIENT] _drainPendingRooms — nothing pending');
      return;
    }

    dLog(
      '🔄 [ChatSocket][CLIENT] _drainPendingRooms — draining '
          '${_pendingRooms.length} room(s): $_pendingRooms',
    );

    final toJoin = Set<int>.from(_pendingRooms);
    _pendingRooms.clear();

    for (final chatId in toJoin) {
      if (_activeChatRooms.contains(chatId)) {
        // Already re-joined by the onConnect handler above — skip.
        dLog(
          'ℹ️  [ChatSocket][CLIENT] _drainPendingRooms — room $chatId '
              'already joined via reconnect handler, skipping duplicate',
        );
        continue;
      }
      dLog(
        '📤 [ChatSocket][CLIENT] _drainPendingRooms — emitting '
            'chat:join for room $chatId',
      );
      _socket!.emit('chat:join', {'chatId': chatId});
      _activeChatRooms.add(chatId);
      dLog(
        '✅ [ChatSocket][CLIENT] Joined pending room $chatId — '
            'activeRooms=$_activeChatRooms',
      );
    }
  }

  // ─── SEND MESSAGE ─────────────────────────────────────────────────────────

  void sendMessage({
    required int chatId,
    required String content,
    required String type,
    void Function(Map<String, dynamic> ack)? onAck,
    void Function()? onError,
  }) {
    dLog(
      '📤 [ChatSocket][CLIENT] sendMessage() — chatId=$chatId, type=$type, '
          'isConnected=$isConnected, isAttached=$isAttached, '
          'inRoom=${_activeChatRooms.contains(chatId)}',
    );

    if (_socket == null) {
      dLog('❌ [ChatSocket][CLIENT] sendMessage failed — socket not attached');
      onError?.call();
      return;
    }

    if (!isConnected) {
      dLog('❌ [ChatSocket][CLIENT] sendMessage failed — not connected');
      onError?.call();
      return;
    }

    if (!_activeChatRooms.contains(chatId)) {
      dLog(
        '⚠️ [ChatSocket][CLIENT] sendMessage — NOT in room $chatId! '
            'Message may not be delivered. Active rooms: $_activeChatRooms',
      );
    }

    dLog(
      '📤 [ChatSocket][CLIENT] Emitting chat:send_message with real ack — '
          'chatId=$chatId',
    );
    _socket!.emitWithAck(
      'chat:send_message',
      {'chatId': chatId, 'content': content, 'type': type},
      ack: (response) {
        dLog(
          '✅ [ChatSocket][CLIENT] sendMessage ack from server → $response',
        );
        final map = _toMap(response) ?? {'success': true};
        onAck?.call(map);
      },
    );
  }

  // ─── TYPING ───────────────────────────────────────────────────────────────

  void emitTyping(int chatId) {
    if (_socket == null) {
      dLog(
        '⚠️ [ChatSocket][CLIENT] emitTyping($chatId) — socket null, skipping',
      );
      return;
    }
    dLog('✏️  [ChatSocket][CLIENT] emitTyping($chatId)');
    _socket!.emit('chat:typing', {'chatId': chatId});
  }

  void emitStopTyping(int chatId) {
    if (_socket == null) {
      dLog(
        '⚠️ [ChatSocket][CLIENT] emitStopTyping($chatId) — socket null, skipping',
      );
      return;
    }
    dLog('⏹️  [ChatSocket][CLIENT] emitStopTyping($chatId)');
    _socket!.emit('chat:stop_typing', {'chatId': chatId});
  }

  // ─── READ RECEIPTS ────────────────────────────────────────────────────────

  void markRead(int chatId) {
    dLog(
      '👁️  [ChatSocket][CLIENT] markRead($chatId) — '
          'isConnected=$isConnected, isAttached=$isAttached',
    );
    if (_socket == null) {
      dLog(
        '⚠️ [ChatSocket][CLIENT] markRead($chatId) — socket null, skipping',
      );
      return;
    }
    _socket!.emit('chat:read_messages', {'chatId': chatId});
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
    dLog(
      '⚠️ [ChatSocket][CLIENT] _toMap failed — unexpected type: '
          '${data.runtimeType}, value: $data',
    );
    return null;
  }
}