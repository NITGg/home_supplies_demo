// courier — chat_socket_service.dart
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:tawreedat_courier/core/utils/secure_storage_service.dart';
import 'package:tawreedat_courier/core/utils/socket_service.dart';

import '../../../core/utils/logger.dart';

class ChatSocketService {
  static final ChatSocketService _instance = ChatSocketService._internal();

  factory ChatSocketService() => _instance;

  ChatSocketService._internal();

  IO.Socket? _socket;
  bool _isBorrowed = false;
  bool _isViaSocketService = false;

  // ── Auth refresh state (owned mode only) ──────────────────────────────────
  bool _isRefreshingToken = false;
  int _authErrorCount = 0;
  static const int _maxAuthErrors = 5;

  Future<String?> Function()? _onTokenExpired;

  String? _ownedBaseUrl;
  String? _ownedToken;
  String? _ownedSocketPath;

  int _ownedGen = 0;

  // ── FIX: flag set during disconnect() to cancel any in-flight auth refresh
  bool _isDisconnecting = false;

  // ── Reconnect-aware room rejoin (borrowed / via-socket-service modes) ─────
  // Handler references kept so detach() can remove *only* our listeners
  // without disturbing SocketService's own connect/disconnect handlers on
  // the same (shared/borrowed) socket instance.
  void Function(dynamic)? _borrowedConnectHandler;
  void Function(dynamic)? _borrowedDisconnectHandler;
  StreamSubscription<bool>? _viaSocketServiceConnSub;

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

  // ─── Active Rooms ──────────────────────────────────────────────────────────
  final Set<int> _activeChatRooms = {};

  // ─── Public Streams ────────────────────────────────────────────────────────
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;
  Stream<Map<String, dynamic>> get onUserStoppedTyping =>
      _userStoppedTypingController.stream;
  Stream<Map<String, dynamic>> get onMessageRead =>
      _messageReadController.stream;
  Stream<bool> get onConnectionStatus => _connectionStatusController.stream;

  bool get isConnected {
    if (_isViaSocketService) return SocketService().isConnected;
    return _socket?.connected ?? false;
  }

  bool get isBorrowed => _isBorrowed;
  bool get isViaSocketService => _isViaSocketService;
  Set<int> get activeChatRooms => Set.unmodifiable(_activeChatRooms);

  // ─── Token refresh injection ───────────────────────────────────────────────
  void setTokenRefreshCallback(Future<String?> Function() onRefresh) {
    _onTokenExpired = onRefresh;
    dLog('🔑 [ChatSocket][COURIER] Token refresh callback registered');
  }

  // ─── MODE A: BORROWED ─────────────────────────────────────────────────────
  void borrowSocket(IO.Socket socket) {
    dLog(
      '🔗 [ChatSocket][COURIER] borrowSocket() called '
          '(socket.connected=${socket.connected}, id=${socket.id})',
    );
    if (_socket != null || _isViaSocketService) detach();
    _socket = socket;
    _isBorrowed = true;
    _isViaSocketService = false;
    _setupChatEventListeners();

    // Keep connection status live and re-join active rooms whenever this
    // (shared) socket connects/reconnects — covers both a reconnect of the
    // SAME socket object and a fresh borrow of a brand-new one.
    _borrowedConnectHandler = (_) {
      dLog(
        '🔄 [ChatSocket][COURIER] Borrowed socket connected/reconnected — '
            'rejoining ${_activeChatRooms.length} room(s): $_activeChatRooms',
      );
      _connectionStatusController.add(true);
      _rejoinActiveRooms();
    };
    _borrowedDisconnectHandler = (_) {
      dLog('🔄 [ChatSocket][COURIER] Borrowed socket disconnected');
      _connectionStatusController.add(false);
    };
    socket.on('connect', _borrowedConnectHandler!);
    socket.on('disconnect', _borrowedDisconnectHandler!);

    _connectionStatusController.add(socket.connected);
    if (socket.connected) _rejoinActiveRooms();

    dLog(
      '🔗 [ChatSocket][COURIER] Borrowed socket — mode=BORROWED, '
          'connected=${socket.connected}',
    );
  }

  // ─── MODE B: VIA SOCKET SERVICE ───────────────────────────────────────────
  void useSocketServiceTransport() {
    dLog(
      '📡 [ChatSocket][COURIER] useSocketServiceTransport() called '
          '(SocketService.isConnected=${SocketService().isConnected})',
    );
    if (_socket != null || _isViaSocketService) detach();
    _isViaSocketService = true;
    _isBorrowed = false;
    _socket = null;

    // Re-join active rooms whenever SocketService (re)connects — its
    // underlying socket may be torn down and recreated (e.g. foreground
    // service restarts, direct/task-isolate mode switches) without this
    // class being notified any other way.
    _viaSocketServiceConnSub?.cancel();
    _viaSocketServiceConnSub = SocketService().onConnectionChanged.listen((connected) {
      dLog(
        '🔄 [ChatSocket][COURIER] SocketService connection changed: $connected',
      );
      _connectionStatusController.add(connected);
      if (connected) _rejoinActiveRooms();
    });

    _connectionStatusController.add(SocketService().isConnected);
    if (SocketService().isConnected) _rejoinActiveRooms();

    dLog('📡 [ChatSocket][COURIER] Mode=VIA_SOCKET_SERVICE');
  }

  void dispatchIncomingEvent(String event, Map<String, dynamic> data) {
    dLog('📨 [ChatSocket][COURIER] dispatchIncomingEvent: $event → $data');
    switch (event) {
      case 'chat:new_message':
        dLog('💬 [ChatSocket][COURIER] chat:new_message (isolate) → $data');
        _newMessageController.add(data);
      case 'chat:user_typing':
        dLog('✏️  [ChatSocket][COURIER] chat:user_typing (isolate) → $data');
        _userTypingController.add(data);
      case 'chat:user_stopped_typing':
        dLog(
          '⏹️  [ChatSocket][COURIER] chat:user_stopped_typing (isolate) → $data',
        );
        _userStoppedTypingController.add(data);
      case 'chat:message_read':
        dLog('✅ [ChatSocket][COURIER] chat:message_read (isolate) → $data');
        _messageReadController.add(data);
      default:
        dLog(
          '⚠️ [ChatSocket][COURIER] dispatchIncomingEvent: unknown event "$event"',
        );
    }
  }

  // ─── MODE C: OWNED ────────────────────────────────────────────────────────
  void connect({
    required String baseUrl,
    required String accessToken,
    String socketPath = '/socket.io',
  }) {
    dLog(
      '🔌 [ChatSocket][COURIER] connect() called — baseUrl=$baseUrl, '
          'path=$socketPath, alreadyConnected=${_socket?.connected}',
    );

    if (_socket?.connected ?? false) {
      dLog('✅ [ChatSocket][COURIER] Already connected — skipping');
      return;
    }
    if (_socket != null || _isViaSocketService) detach();

    _isBorrowed = false;
    _isViaSocketService = false;
    _isRefreshingToken = false;
    _isDisconnecting = false;
    _authErrorCount = 0;

    _ownedBaseUrl = baseUrl;
    _ownedToken = accessToken;
    _ownedSocketPath = socketPath;

    _connectOwned(baseUrl: baseUrl, token: accessToken, socketPath: socketPath);
  }

  void _connectOwned({
    required String baseUrl,
    required String token,
    required String socketPath,
  }) {
    _destroyOwnedSocket();

    final gen = ++_ownedGen;
    dLog(
      '🔌 [ChatSocket][COURIER] _connectOwned() gen=$gen to $baseUrl$socketPath',
    );

    final uri = Uri.parse(baseUrl);
    final normalizedUrl = uri.hasPort && uri.port != 0
        ? baseUrl
        : uri.replace(port: uri.scheme == 'https' ? 443 : 80).toString();

    dLog(
      '🔌 [ChatSocket][COURIER] Normalized URL: $normalizedUrl (original: $baseUrl)',
    );

    _socket = IO.io(
      normalizedUrl,
      IO.OptionBuilder()
          .setPath(socketPath)
          .setTransports(['websocket'])
          .setAuth({'accessToken': 'Bearer $token'})
          .setReconnectionAttempts(-1)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(60000)
          .enableReconnection()
          .enableAutoConnect()
          .enableForceNew()
          .build(),
    );

    _socket!.onConnect((_) {
      if (gen != _ownedGen) {
        dLog(
          '🚫 [ChatSocket][COURIER] onConnect fired for stale gen=$gen '
              '(current=$_ownedGen) — ignoring',
        );
        return;
      }
      dLog(
        '✅ [ChatSocket][COURIER] Connected! id=${_socket!.id}, gen=$gen, '
            'activeRooms=$_activeChatRooms',
      );
      _isRefreshingToken = false;
      _authErrorCount = 0;
      _connectionStatusController.add(true);

      // Re-join every active room after reconnect.
      _rejoinActiveRooms();
    });

    _socket!.onDisconnect((reason) {
      if (gen != _ownedGen) {
        dLog(
          '🚫 [ChatSocket][COURIER] onDisconnect fired for stale gen=$gen — ignoring',
        );
        return;
      }
      dLog(
        '❌ [ChatSocket][COURIER] Disconnected! reason="$reason", gen=$gen, '
            'activeRooms=$_activeChatRooms',
      );
      _connectionStatusController.add(false);

      if (reason?.toString() == 'io server disconnect') {
        dLog(
          '🔑 [ChatSocket][COURIER] Server-side disconnect — likely auth expiry, '
              'triggering token refresh',
        );
        _handleAuthExpired(gen);
      }
    });

    _socket!.onConnectError((e) {
      if (gen != _ownedGen) {
        dLog(
          '🚫 [ChatSocket][COURIER] onConnectError for stale gen=$gen — ignoring',
        );
        return;
      }
      dLog('⚠️ [ChatSocket][COURIER] Connect error: $e, gen=$gen');
      if (_isAuthError(e)) {
        dLog('🔑 [ChatSocket][COURIER] Auth error detected in connect error');
        _handleAuthExpired(gen);
      }
    });

    _socket!.onError((e) {
      if (gen != _ownedGen) {
        dLog(
          '🚫 [ChatSocket][COURIER] onError for stale gen=$gen — ignoring',
        );
        return;
      }
      dLog('❌ [ChatSocket][COURIER] Socket error: $e, gen=$gen');
      if (_isAuthError(e)) {
        dLog('🔑 [ChatSocket][COURIER] Auth error detected in socket error');
        _handleAuthExpired(gen);
      }
    });

    _socket!.on('auth:expired', (_) {
      if (gen != _ownedGen) {
        dLog(
          '🚫 [ChatSocket][COURIER] auth:expired for stale gen=$gen — ignoring',
        );
        return;
      }
      dLog('🔑 [ChatSocket][COURIER] auth:expired event received from server');
      _handleAuthExpired(gen);
    });

    _setupChatEventListeners(gen: gen);
    dLog('🔌 [ChatSocket][COURIER] Calling socket.connect() for gen=$gen');
    _socket!.connect();
  }

  // ─── Auth refresh (owned mode only) ───────────────────────────────────────
  Future<void> _handleAuthExpired(int gen) async {
    if (gen != _ownedGen) {
      dLog(
        '🚫 [ChatSocket][COURIER] _handleAuthExpired: stale gen=$gen, '
            'current=$_ownedGen — ignoring',
      );
      return;
    }

    // FIX: bail out immediately if disconnect() is in progress — this prevents
    // the null assertion crash on _ownedBaseUrl! / _ownedSocketPath! that would
    // occur if those fields were already cleared.
    if (_isDisconnecting) {
      dLog(
        '🚫 [ChatSocket][COURIER] _handleAuthExpired: disconnect in progress — ignoring',
      );
      return;
    }

    if (_isRefreshingToken) {
      dLog(
        '🔁 [ChatSocket][COURIER] _handleAuthExpired: refresh already in '
            'progress — skipping',
      );
      return;
    }

    _authErrorCount++;
    dLog(
      '🔑 [ChatSocket][COURIER] _handleAuthExpired: attempt '
          '$_authErrorCount/$_maxAuthErrors',
    );

    if (_authErrorCount > _maxAuthErrors) {
      dLog(
        '🚫 [ChatSocket][COURIER] Max auth errors ($_maxAuthErrors) reached '
            '— giving up and disconnecting',
      );
      _authErrorCount = 0;
      _isRefreshingToken = false;
      disconnect();
      return;
    }

    if (_onTokenExpired == null) {
      dLog(
        '⚠️ [ChatSocket][COURIER] No token-refresh callback registered — '
            'cannot refresh',
      );
      return;
    }

    _isRefreshingToken = true;
    dLog(
      '🔑 [ChatSocket][COURIER] Calling token refresh callback '
          '(attempt $_authErrorCount/$_maxAuthErrors)…',
    );

    try {
      final newToken = await _onTokenExpired!();

      // FIX: re-check disconnect flag after the async gap — the user may have
      // logged out while the HTTP refresh was in flight.
      if (_isDisconnecting) {
        dLog(
          '🚫 [ChatSocket][COURIER] _handleAuthExpired: disconnect occurred '
              'during token fetch — aborting reconnect',
        );
        return;
      }

      if (newToken == null || newToken.isEmpty) {
        dLog(
          '❌ [ChatSocket][COURIER] Refresh returned null/empty — disconnecting',
        );
        disconnect();
        return;
      }

      if (newToken == _ownedToken) {
        dLog(
          '⚠️ [ChatSocket][COURIER] Token unchanged after refresh — '
              'retrying in 3 s',
        );
        await Future.delayed(const Duration(seconds: 3));
        _isRefreshingToken = false;
        _handleAuthExpired(gen);
        return;
      }

      _ownedToken = newToken;
      _authErrorCount = 0;
      dLog(
        '✅ [ChatSocket][COURIER] Token refreshed successfully — '
            'reconnecting chat socket',
      );

      await SecureStorageService().saveToken(newToken);
      dLog('💾 [ChatSocket][COURIER] New token persisted to SecureStorage');

      // FIX: guard against nulls that would cause a crash if disconnect() raced
      // with this async block.
      final baseUrl = _ownedBaseUrl;
      final socketPath = _ownedSocketPath;
      if (baseUrl == null || socketPath == null || _isDisconnecting) {
        dLog(
          '⚠️ [ChatSocket][COURIER] Owned credentials cleared before reconnect '
              '— aborting',
        );
        return;
      }

      _connectOwned(
        baseUrl: baseUrl,
        token: newToken,
        socketPath: socketPath,
      );
    } catch (e, stack) {
      dLog('❌ [ChatSocket][COURIER] Token refresh threw: $e\n$stack');
      _authErrorCount = 0;
      disconnect();
    } finally {
      _isRefreshingToken = false;
    }
  }

  // ─── Listeners ─────────────────────────────────────────────────────────────
  void _setupChatEventListeners({int? gen}) {
    dLog(
      '👂 [ChatSocket][COURIER] Registering chat event listeners '
          '(gen=${gen ?? "borrowed"})',
    );

    _socket!.on('chat:new_message', (data) {
      if (gen != null && gen != _ownedGen) {
        dLog(
          '🚫 [ChatSocket][COURIER] chat:new_message stale gen=$gen — ignoring',
        );
        return;
      }
      dLog('💬 [ChatSocket][COURIER] chat:new_message received → $data');
      final map = _toMap(data);
      if (map != null) {
        dLog(
          '💬 [ChatSocket][COURIER] chat:new_message — pushing to stream, '
              'listeners=${_newMessageController.hasListener}',
        );
        _newMessageController.add(map);
      } else {
        dLog(
          '⚠️ [ChatSocket][COURIER] chat:new_message — could not parse data: $data',
        );
      }
    });

    _socket!.on('chat:user_typing', (data) {
      if (gen != null && gen != _ownedGen) return;
      dLog('✏️  [ChatSocket][COURIER] chat:user_typing → $data');
      final map = _toMap(data);
      if (map != null) _userTypingController.add(map);
    });

    _socket!.on('chat:user_stopped_typing', (data) {
      if (gen != null && gen != _ownedGen) return;
      dLog('⏹️  [ChatSocket][COURIER] chat:user_stopped_typing → $data');
      final map = _toMap(data);
      if (map != null) _userStoppedTypingController.add(map);
    });

    _socket!.on('chat:message_read', (data) {
      if (gen != null && gen != _ownedGen) return;
      dLog('✅ [ChatSocket][COURIER] chat:message_read → $data');
      final map = _toMap(data);
      if (map != null) _messageReadController.add(map);
    });

    dLog('👂 [ChatSocket][COURIER] Chat event listeners registered ✓');
  }

  /// Re-emits `chat:join` for every room in [_activeChatRooms].
  ///
  /// Called whenever the underlying transport (re)connects — owned socket
  /// reconnect, borrowed socket reconnect/replacement, or SocketService
  /// connection-state flip — so the server-side room membership always
  /// matches what the UI thinks is "joined", even across socket teardown
  /// and recreation.
  void _rejoinActiveRooms() {
    if (_activeChatRooms.isEmpty) {
      dLog('ℹ️  [ChatSocket][COURIER] No active rooms to re-join');
      return;
    }
    dLog(
      '🔁 [ChatSocket][COURIER] Re-joining ${_activeChatRooms.length} '
          'room(s): $_activeChatRooms',
    );
    for (final chatId in _activeChatRooms) {
      dLog('🔗 [ChatSocket][COURIER] Re-emitting chat:join for room $chatId');
      if (_isViaSocketService) {
        SocketService().emitChatEvent('chat:join', {'chatId': chatId});
      } else {
        _socket?.emit('chat:join', {'chatId': chatId});
      }
    }
  }

  // ─── Room Management ──────────────────────────────────────────────────────
  void joinChat(int chatId) {
    dLog(
      '🔗 [ChatSocket][COURIER] joinChat($chatId) — isConnected=$isConnected, '
          'alreadyActive=${_activeChatRooms.contains(chatId)}, '
          'activeRooms=$_activeChatRooms, mode='
          '${_isViaSocketService ? "VIA_SOCKET_SERVICE" : _isBorrowed ? "BORROWED" : "OWNED"}',
    );

    if (!isConnected) {
      // Buffer: onConnect will re-join everything in _activeChatRooms
      _activeChatRooms.add(chatId);
      dLog('⚠️ joinChat($chatId) — not connected, buffered for reconnect. '
          'activeRooms=$_activeChatRooms');
      return;
    }
    if (_activeChatRooms.contains(chatId)) {
      dLog('ℹ️ joinChat($chatId) — already in room, skipping');
      return;
    }

    if (_isViaSocketService) {
      dLog(
        '📡 [ChatSocket][COURIER] Emitting chat:join via SocketService for room $chatId',
      );
      SocketService().emitChatEvent('chat:join', {'chatId': chatId});
    } else {
      dLog(
        '📤 [ChatSocket][COURIER] Emitting chat:join directly for room $chatId',
      );
      _socket?.emit('chat:join', {'chatId': chatId});
    }
    _activeChatRooms.add(chatId);
    dLog(
      '✅ [ChatSocket][COURIER] Joined room $chatId — activeRooms=$_activeChatRooms',
    );
  }

  void leaveChat(int chatId) {
    dLog(
      '🔓 [ChatSocket][COURIER] leaveChat($chatId) — '
          'inRooms=${_activeChatRooms.contains(chatId)}, '
          'activeRooms=$_activeChatRooms',
    );

    if (!_activeChatRooms.contains(chatId)) {
      dLog(
        'ℹ️  [ChatSocket][COURIER] leaveChat($chatId) — not in room, skipping',
      );
      return;
    }
    if (_isViaSocketService) {
      SocketService().emitChatEvent('chat:leave', {'chatId': chatId});
    } else {
      _socket?.emit('chat:leave', {'chatId': chatId});
    }
    _activeChatRooms.remove(chatId);
    dLog(
      '✅ [ChatSocket][COURIER] Left room $chatId — activeRooms=$_activeChatRooms',
    );
  }

  // ─── Messaging ────────────────────────────────────────────────────────────
  void sendMessage({
    required int chatId,
    required String content,
    required String type,
    void Function(Map<String, dynamic> ack)? onAck,
    void Function()? onError,
  }) {
    dLog(
      '📤 [ChatSocket][COURIER] sendMessage() — chatId=$chatId, type=$type, '
          'isConnected=$isConnected, mode='
          '${_isViaSocketService ? "VIA_SOCKET_SERVICE" : _isBorrowed ? "BORROWED" : "OWNED"}, '
          'inRoom=${_activeChatRooms.contains(chatId)}',
    );

    if (!isConnected) {
      dLog(
        '❌ [ChatSocket][COURIER] sendMessage failed — not connected',
      );
      onError?.call();
      return;
    }

    if (!_activeChatRooms.contains(chatId)) {
      dLog(
        '⚠️ [ChatSocket][COURIER] sendMessage — NOT in room $chatId! '
            'Message may not be delivered. Active rooms: $_activeChatRooms',
      );
    }

    if (_isViaSocketService) {
      final ackId = 'chat_ack_${DateTime.now().millisecondsSinceEpoch}';
      dLog(
        '📡 [ChatSocket][COURIER] sendMessage via SocketService, ackId=$ackId',
      );
      SocketService().emitChatWithAck(
        'chat:send_message',
        {'chatId': chatId, 'content': content, 'type': type},
        ackId: ackId,
        onAck: (ack) {
          dLog(
            '✅ [ChatSocket][COURIER] sendMessage ack received (isolate) '
                'ackId=$ackId → $ack',
          );
          onAck?.call(ack);
        },
        onError: () {
          dLog(
            '❌ [ChatSocket][COURIER] sendMessage ack failed (isolate) '
                'ackId=$ackId',
          );
          onError?.call();
        },
      );
      return;
    }

    dLog(
      '📤 [ChatSocket][COURIER] Emitting chat:send_message with real ack — '
          'chatId=$chatId',
    );
    _socket!.emitWithAck(
      'chat:send_message',
      {'chatId': chatId, 'content': content, 'type': type},
      ack: (response) {
        dLog(
          '✅ [ChatSocket][COURIER] sendMessage real ack from server → $response',
        );
        final map = _toMap(response) ?? {'success': true};
        onAck?.call(map);
      },
    );
  }

  // ─── Typing ───────────────────────────────────────────────────────────────
  void emitTyping(int chatId) {
    dLog('✏️  [ChatSocket][COURIER] emitTyping($chatId)');
    if (_isViaSocketService) {
      SocketService().emitChatEvent('chat:typing', {'chatId': chatId});
    } else {
      _socket?.emit('chat:typing', {'chatId': chatId});
    }
  }

  void emitStopTyping(int chatId) {
    dLog('⏹️  [ChatSocket][COURIER] emitStopTyping($chatId)');
    if (_isViaSocketService) {
      SocketService().emitChatEvent('chat:stop_typing', {'chatId': chatId});
    } else {
      _socket?.emit('chat:stop_typing', {'chatId': chatId});
    }
  }

  // ─── Read Receipts ────────────────────────────────────────────────────────
  void markRead(int chatId) {
    dLog(
        '👁️  [ChatSocket][COURIER] markRead($chatId) — isConnected=$isConnected');
    if (_isViaSocketService) {
      SocketService().emitChatEvent('chat:read_messages', {'chatId': chatId});
    } else {
      _socket?.emit('chat:read_messages', {'chatId': chatId});
    }
  }

  // ─── Detach ───────────────────────────────────────────────────────────────
  void detach() {
    dLog(
      '🔓 [ChatSocket][COURIER] detach() — mode='
          '${_isViaSocketService ? "VIA_SOCKET_SERVICE" : _isBorrowed ? "BORROWED" : "OWNED"}, '
          'activeRooms=$_activeChatRooms',
    );

    for (final chatId in Set<int>.from(_activeChatRooms)) {
      dLog('🔓 [ChatSocket][COURIER] Leaving room $chatId during detach');
      if (_isViaSocketService) {
        SocketService().emitChatEvent('chat:leave', {'chatId': chatId});
      } else if (_socket != null) {
        _socket!.emit('chat:leave', {'chatId': chatId});
      }
    }
    _activeChatRooms.clear();

    if (_socket != null && !_isViaSocketService) {
      dLog('🔓 [ChatSocket][COURIER] Removing chat listeners from socket');
      _socket!.off('chat:new_message');
      _socket!.off('chat:user_typing');
      _socket!.off('chat:user_stopped_typing');
      _socket!.off('chat:message_read');
      _socket!.off('auth:expired');

      // Only remove the SPECIFIC connect/disconnect handlers we added in
      // borrowSocket() — the socket may be shared with SocketService, which
      // has its own connect/disconnect handlers that must stay intact.
      if (_borrowedConnectHandler != null) {
        _socket!.off('connect', _borrowedConnectHandler);
      }
      if (_borrowedDisconnectHandler != null) {
        _socket!.off('disconnect', _borrowedDisconnectHandler);
      }
    }

    _viaSocketServiceConnSub?.cancel();
    _viaSocketServiceConnSub = null;
    _borrowedConnectHandler = null;
    _borrowedDisconnectHandler = null;

    _socket = null;
    _isBorrowed = false;
    _isViaSocketService = false;
    _isRefreshingToken = false;
    dLog('🔓 [ChatSocket][COURIER] Detached ✓');
  }

  // ─── Disconnect (owned mode) ──────────────────────────────────────────────
  void disconnect() {
    dLog(
      '🔌 [ChatSocket][COURIER] disconnect() — isBorrowed=$_isBorrowed, '
          'isViaSocketService=$_isViaSocketService, activeRooms=$_activeChatRooms',
    );

    // FIX: Set the flag BEFORE clearing credentials so any in-flight
    // _handleAuthExpired sees it before it reaches the null assertion.
    _isDisconnecting = true;

    if (_isBorrowed || _isViaSocketService) {
      detach();
      _isDisconnecting = false;
      return;
    }
    _activeChatRooms.clear();
    _destroyOwnedSocket();
    _ownedBaseUrl = null;
    _ownedToken = null;
    _ownedSocketPath = null;
    _isRefreshingToken = false;
    _authErrorCount = 0;
    _isDisconnecting = false;
    dLog('🔌 [ChatSocket][COURIER] Disconnected and disposed ✓');
  }

  void _destroyOwnedSocket() {
    if (_socket == null) {
      dLog('ℹ️  [ChatSocket][COURIER] _destroyOwnedSocket — nothing to destroy');
      return;
    }
    dLog('💥 [ChatSocket][COURIER] Destroying owned socket (id=${_socket!.id})');
    _socket!.offAny();
    _socket!.disconnect();
    _socket!.dispose();
    _socket = null;
    dLog('💥 [ChatSocket][COURIER] Owned socket destroyed ✓');
  }

  void dispose() {
    dLog('🗑️  [ChatSocket][COURIER] dispose() called');
    disconnect();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  bool _isAuthError(dynamic error) {
    if (error == null) return false;
    final msg = (error is Map
        ? (error['message'] ?? error.toString())
        : error.toString())
        .toLowerCase();
    final result = msg.contains('unauthorized') ||
        msg.contains('jwt expired') ||
        msg.contains('invalid token') ||
        msg.contains('jwt malformed') ||
        msg.contains('token_expired');
    if (result) {
      dLog('🔑 [ChatSocket][COURIER] _isAuthError=true for: $msg');
    }
    return result;
  }

  Map<String, dynamic>? _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    dLog(
      '⚠️ [ChatSocket][COURIER] _toMap failed — unexpected type: '
          '${data.runtimeType}, value: $data',
    );
    return null;
  }
}