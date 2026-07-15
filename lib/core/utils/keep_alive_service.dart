//courier

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:tawreedat_courier/core/utils/socket_location_utils.dart';

import 'api_client.dart';
import 'logger.dart';
import 'logger.dart' as logger;

// ── Storage keys ──────────────────────────────────────────────────────────────
const _kBaseUrlKey = 'ka_base_url';
const _kSupplierBaseUrlKey = 'ka_supplier_base_url';
const _kTokenKey = 'ka_token';
const _kRefreshTokenKey = 'ka_refresh_token';
const _kDebugKey = 'ka_debugging';
const _kAvailableKey = 'ka_available';

// ── Background entry-point ────────────────────────────────────────────────────
@pragma('vm:entry-point')
void keepAliveCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

// ── Task handler ──────────────────────────────────────────────────────────────
class _KeepAliveHandler extends TaskHandler {
  IO.Socket? _socket;
  IO.Socket? _supplierSocket;
  String _baseUrl = '';
  String _supplierBaseUrl = '';
  String _token = '';
  String _refreshToken = '';

  bool _waitingForTokenUpdate = false;
  int _waitingHeartbeats = 0;
  static const int _maxWaitHeartbeats = 2;

  bool _isSelfRefreshing = false;

  // ── Debug logging (kDebugMode is always false in background isolates) ─────
  bool _debugLogging = false;

  void dLog(String msg) {
    if (_debugLogging) logger.dLog(msg); // use the import prefix
  }

  // ── Location tracking ─────────────────────────────────────────────────────
  int? _trackingOrderId;
  int _locationTick = 0;
  static const int _locationTickInterval = 1; //= the keep alive ticker 1 = 30s

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _debugLogging =
        (await FlutterForegroundTask.getData<bool>(key: _kDebugKey)) ?? false;
    dLog('✅ [KeepAlive] Task isolate started (starter: ${starter.name})');

    _baseUrl =
        (await FlutterForegroundTask.getData<String>(key: _kBaseUrlKey)) ?? '';
    _supplierBaseUrl =
        (await FlutterForegroundTask.getData<String>(
          key: _kSupplierBaseUrlKey,
        )) ??
        '';
    _token =
        (await FlutterForegroundTask.getData<String>(key: _kTokenKey)) ?? '';
    _refreshToken =
        (await FlutterForegroundTask.getData<String>(key: _kRefreshTokenKey)) ??
        '';

    // ← Check persisted availability flag BEFORE connecting.
    // This prevents auto-restart (boot/replace) from marking the courier online
    // when they explicitly went unavailable.
    final isAvailable =
        (await FlutterForegroundTask.getData<bool>(key: _kAvailableKey)) ??
        true;

    if (!isAvailable) {
      dLog(
        'ℹ️ [KeepAlive] onStart — courier is unavailable, staying disconnected',
      );
      _baseUrl = _token = _refreshToken = _supplierBaseUrl = '';
      return;
    }

    if (_baseUrl.isNotEmpty && _token.isNotEmpty) {
      dLog('🔌 [KeepAlive] onStart — connecting with persisted credentials');
      _connectSocket();
    } else {
      dLog(
        '⚠️ [KeepAlive] onStart — no credentials, waiting for connect command',
      );
    }
  }

  /// Called every 30 s.
  // In onRepeatEvent — add an explicit availability guard so a boot/replace
// restart never reconnects when the courier is unavailable:
  @override
  void onRepeatEvent(DateTime timestamp) {
    final alive = _socket?.connected ?? false;
    dLog('💓 [KeepAlive] Heartbeat — socket ${alive ? "alive ✅" : "dead ❌"}');

    if (alive && _trackingOrderId != null) {
      _locationTick++;
      if (_locationTick >= _locationTickInterval) {
        _locationTick = 0;
        _emitLocationUpdate(_trackingOrderId!);
      }
    }

    if (alive) {
      _waitingHeartbeats = 0;
      return;
    }

    if (_waitingForTokenUpdate) {
      _waitingHeartbeats++;
      if (_waitingHeartbeats >= _maxWaitHeartbeats) {
        _selfRefreshToken();
      }
      return;
    }

    // Only reconnect if we actually have credentials — an empty _baseUrl
    // means the courier explicitly disconnected; don't touch the socket.
    if (_baseUrl.isEmpty || _token.isEmpty) {
      dLog('ℹ️ [KeepAlive] Heartbeat — no credentials, staying disconnected');
      return;
    }

    dLog('🔄 [KeepAlive] Heartbeat reconnecting socket...');
    _connectSocket();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    dLog('🛑 [KeepAlive] Task destroyed (timeout: $isTimeout)');
    _destroySocket();
  }

  // Add this helper to fully kill both sockets with no auto-reconnect
  void _destroySocket() {
    if (_socket != null) {
      _socket!.clearListeners();
      _socket!.disconnect(); // ← sends close frame to server
      _socket!.dispose();    // ← cleans up client-side engine
      _socket = null;
    }
    if (_supplierSocket != null) {
      _supplierSocket!.clearListeners();
      _supplierSocket!.disconnect(); // ← same
      _supplierSocket!.dispose();
      _supplierSocket = null;
    }
    dLog('🔌 [KeepAlive] Sockets destroyed and disconnected');
  }

  // ── Commands from the main isolate ────────────────────────────────────────

  @override
  void onReceiveData(Object data) {
    if (data is! Map<String, dynamic>) return;

    final command = data['command'] as String?;
    dLog('📨 [KeepAlive] Received command: $command');

    switch (command) {
      // ── Existing commands ─────────────────────────────────────────────────
      case 'connect':
        final url = data['baseUrl'] as String? ?? '';
        final supplierUrl = data['supplierBaseUrl'] as String? ?? '';
        final token = data['token'] as String? ?? '';
        final refreshToken = data['refreshToken'] as String? ?? '';
        if (url.isEmpty || token.isEmpty) return;
        _baseUrl = url;
        _supplierBaseUrl = supplierUrl;
        _token = token;
        _refreshToken = refreshToken;
        _waitingForTokenUpdate = false;
        _waitingHeartbeats = 0;
        FlutterForegroundTask.saveData(key: _kBaseUrlKey, value: _baseUrl);
        FlutterForegroundTask.saveData(
          key: _kSupplierBaseUrlKey,
          value: _supplierBaseUrl,
        );
        FlutterForegroundTask.saveData(key: _kTokenKey, value: _token);
        FlutterForegroundTask.saveData(
          key: _kRefreshTokenKey,
          value: _refreshToken,
        );
        _connectSocket();

      case 'reconnect':
        if (_baseUrl.isNotEmpty && _token.isNotEmpty) {
          dLog('🔄 [KeepAlive] Reconnect command received');
          _waitingForTokenUpdate = false;
          _waitingHeartbeats = 0;
          _connectSocket();
        } else {
          dLog('⚠️ [KeepAlive] Reconnect command ignored — no credentials');
        }

      case 'updateToken':
        final newToken = data['token'] as String? ?? '';
        final newRefreshToken =
            data['refreshToken'] as String? ?? _refreshToken;
        if (newToken.isEmpty) return;
        _token = newToken;
        _refreshToken = newRefreshToken;
        _waitingForTokenUpdate = false;
        _waitingHeartbeats = 0;
        FlutterForegroundTask.saveData(key: _kTokenKey, value: _token);
        FlutterForegroundTask.saveData(
          key: _kRefreshTokenKey,
          value: _refreshToken,
        );
        dLog('🔑 [KeepAlive] Token updated — reconnecting');
        _destroySocket();
        _connectSocket();

      case 'disconnect':
        // Clear credentials first so heartbeat can't race and reconnect.
        _baseUrl = _token = _refreshToken = _supplierBaseUrl = '';
        _waitingForTokenUpdate = false;
        _waitingHeartbeats = 0;
        _trackingOrderId = null;
        _locationTick = 0;
        FlutterForegroundTask.saveData(key: _kBaseUrlKey, value: '');
        FlutterForegroundTask.saveData(key: _kSupplierBaseUrlKey, value: '');
        FlutterForegroundTask.saveData(key: _kTokenKey, value: '');
        FlutterForegroundTask.saveData(key: _kRefreshTokenKey, value: '');
        _destroySocket(); // ← destroy AFTER clearing, order matters
        dLog('🔌 [KeepAlive] Disconnected by command, credentials cleared');

      case 'socket:emit':
        final event = data['event'] as String? ?? '';
        final payload = data['payload'];
        dLog('📨 [KeepAlive] Event $event payload: $payload');
        if (event.isNotEmpty) {
          _socket?.emit(
            event,
            payload is Map ? Map<String, dynamic>.from(payload) : payload,
          );
        }

      case 'socket:emit_with_ack':
        final event = data['event'] as String? ?? '';
        final payload = data['payload'];
        final ackId = data['ackId'] as String? ?? '';
        if (event.isNotEmpty && ackId.isNotEmpty && _socket != null) {
          _socket!.emitWithAck(
            event,
            payload is Map ? Map<String, dynamic>.from(payload) : payload,
            ack: (rawAck) {
              _sendToMain({
                'event': 'socket:ack',
                'ackId': ackId,
                'data': rawAck is Map
                    ? _toSafeMap(rawAck)
                    : (rawAck == true || rawAck == 'ok')
                    ? {'success': true}
                    : <String, dynamic>{},
              });
            },
          );
        }

      // ── Location tracking commands ────────────────────────────────────────

      case 'tracking:start':
        final orderId = data['orderId'] as int?;
        if (orderId == null) return;
        _trackingOrderId = orderId;
        _locationTick = 0;
        dLog(
          '📍 [KeepAlive] Background location tracking started for order $orderId',
        );

      case 'tracking:stop':
        _trackingOrderId = null;
        _locationTick = 0;
        dLog('📍 [KeepAlive] Background location tracking stopped');

      case 'location:get':
        if (_socket?.connected ?? false) {
          _emitLocationOnDemand();
        }
    }
  }

  Future<void> _emitLocationOnDemand() async {
    final position = await LocationUtils.getCurrentPosition();
    if (position == null) return;
    _socket?.emit('courier:location_response', {
      'lat': position.latitude,
      'lng': position.longitude,
    });
    dLog('📍 [KeepAlive] On-demand location sent');
  }

  // ── Background location update ────────────────────────────────────────────

  Future<void> _emitLocationUpdate(int orderId) async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        dLog('⚠️ [KeepAlive] Location permission denied — skipping update');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final uri = Uri.parse('${ApiClient.baseUrl}/order/$orderId/location');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.patchUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $_token');
      request.write(
        jsonEncode({'lat': position.latitude, 'lng': position.longitude}),
      );

      final response = await request.close();
      await response.drain<void>();
      client.close();

      dLog(
        '📍 [KeepAlive] PATCH location order=$orderId '
        '${position.latitude}, ${position.longitude} → HTTP ${response.statusCode}',
      );
    } catch (e) {
      dLog('⚠️ [KeepAlive] Background location update failed: $e');
    }
  }

  // ── Self-refresh ──────────────────────────────────────────────────────────

  Future<void> _selfRefreshToken() async {
    if (_isSelfRefreshing) {
      dLog('🔁 [KeepAlive] Self-refresh already in progress — skipping');
      return;
    }
    if (_refreshToken.isEmpty) {
      dLog('❌ [KeepAlive] No refresh token — cannot self-refresh, giving up');
      _waitingForTokenUpdate = false;
      _waitingHeartbeats = 0;
      return;
    }
    _isSelfRefreshing = true;
    try {
      final refreshUrl = _buildRefreshUrl(_baseUrl);
      dLog('🔑 [KeepAlive] Self-refreshing token via $refreshUrl');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(Uri.parse(refreshUrl));
      request.headers.set('Authorization', 'Bearer $_refreshToken');
      request.headers.set('Content-Type', 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();
      if (response.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final newToken = json['data']?['accessToken'] as String?;
        final newRefresh =
            json['data']?['refreshToken'] as String? ?? _refreshToken;
        if (newToken != null && newToken.isNotEmpty) {
          _token = newToken;
          _refreshToken = newRefresh;
          _waitingForTokenUpdate = false;
          _waitingHeartbeats = 0;
          await FlutterForegroundTask.saveData(key: _kTokenKey, value: _token);
          await FlutterForegroundTask.saveData(
            key: _kRefreshTokenKey,
            value: _refreshToken,
          );
          dLog('✅ [KeepAlive] Self-refresh succeeded — reconnecting');
          _connectSocket();
          _sendToMain({
            'event': 'token_refreshed',
            'token': _token,
            'refreshToken': _refreshToken,
          });
          return;
        }
      }
      dLog(
        '❌ [KeepAlive] Self-refresh rejected (HTTP ${response.statusCode}) — giving up',
      );
      _waitingForTokenUpdate = false;
      _waitingHeartbeats = 0;
    } catch (e) {
      dLog(
        '⚠️ [KeepAlive] Self-refresh network error: $e — will retry next heartbeat',
      );
      _waitingHeartbeats = 0;
    } finally {
      _isSelfRefreshing = false;
    }
  }

  String _buildRefreshUrl(String baseUrl) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$base/courier_apis/api/v1/courier/auth/refresh-token';
  }

  // ── Socket management ─────────────────────────────────────────────────────

  void _connectSocket() {
    if (_baseUrl.isEmpty || _token.isEmpty) {
      dLog('⚠️ [KeepAlive] Cannot connect — missing credentials');
      return;
    }
    _destroySocket();
    dLog('🔌 [KeepAlive] Connecting socket to $_baseUrl');

    _socket = IO.io(
      _baseUrl,
      IO.OptionBuilder()
          .setPath('/admin_apis/socket.io')
          .setTransports(['websocket'])
          .setAuth({'token': _token})
          .setReconnectionAttempts(-1)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(60000)
          .enableReconnection()
          .enableAutoConnect()
          .enableForceNew()
          .build(),
    );

    _socket!.onConnect((_) {
      dLog('✅ [KeepAlive] Socket connected: ${_socket?.id}');
      _waitingForTokenUpdate = false;
      _waitingHeartbeats = 0;
      _sendToMain({'event': 'connection_state', 'connected': true});
    });

    _socket!.onDisconnect((reason) {
      final r = reason?.toString() ?? 'unknown';
      dLog('❌ [KeepAlive] Socket disconnected: $r');
      _sendToMain({'event': 'connection_state', 'connected': false});
      if (r == 'io server disconnect') {
        _waitingForTokenUpdate = true;
        _waitingHeartbeats = 0;
        _sendToMain({'event': 'auth:expired'});
      }
    });

    _socket!.onConnectError((error) {
      dLog('⚠️ [KeepAlive] Connect error: $error');
      if (_isAuthError(error)) {
        _waitingForTokenUpdate = true;
        _waitingHeartbeats = 0;
        _sendToMain({'event': 'auth:expired'});
      }
    });

    _socket!.onError((error) {
      dLog('❌ [KeepAlive] Socket error: $error');
      if (_isAuthError(error)) {
        _waitingForTokenUpdate = true;
        _waitingHeartbeats = 0;
        _sendToMain({'event': 'auth:expired'});
      }
    });

    const businessEvents = [
      'order:new',
      'order:cancelled',
      'offer:accepted',
      'offer:rejected',
      'priceReport:response',
      'order:taken',
      'offer:new',
      'chat:new_message',
      'chat:user_typing',
      'chat:user_stopped_typing',
      'chat:message_read',
      'order:delivery_confirmed_customer',
    ];

    for (final eventName in businessEvents) {
      _socket!.on(eventName, (data) {
        dLog('📨 [KeepAlive] Event $eventName');
        _sendToMain({'event': eventName, 'data': _toSafeMap(data)});
      });
    }

    _socket!.on('auth:expired', (_) {
      dLog('🔑 [KeepAlive] auth:expired event from server');
      _waitingForTokenUpdate = true;
      _waitingHeartbeats = 0;
      _sendToMain({'event': 'auth:expired'});
    });

    _socket!.on('courier:get_location', (_) => _emitLocationOnDemand());

    _socket!.connect();
    _connectSupplierSocket();
  }

  // ── Supplier socket ───────────────────────────────────────────────────────
  //
  // Connects to https://tawreedatsupplierapis.nitg-eg.com
  // Falls back to _baseUrl if _supplierBaseUrl is not set.

  void _connectSupplierSocket() {
    final supplierUrl = _supplierBaseUrl.isNotEmpty ? _supplierBaseUrl : _baseUrl;
    if (supplierUrl.isEmpty || _token.isEmpty) return;

    // _destroySocket() already nulled _supplierSocket before we get here,
    // so no inline teardown needed — just build the new socket.
    dLog('🔌 [KeepAlive] Connecting supplier socket to $supplierUrl');

    _supplierSocket = IO.io(
      supplierUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'accessToken': 'Bearer $_token'})
          .setReconnectionAttempts(-1)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(60000)
          .enableReconnection()
          .enableAutoConnect()
          .enableForceNew()
          .build(),
    );

    _supplierSocket!.onConnect((_) {
      dLog('✅ [KeepAlive] Supplier socket connected: ${_supplierSocket?.id}');
    });

    _supplierSocket!.onDisconnect((reason) {
      final r = reason?.toString() ?? 'unknown';
      dLog('❌ [KeepAlive] Supplier socket disconnected: $r');
      if (r == 'io server disconnect') {
        _waitingForTokenUpdate = true;
        _waitingHeartbeats = 0;
        _sendToMain({'event': 'auth:expired'});
      }
    });

    _supplierSocket!.onConnectError((error) {
      dLog('⚠️ [KeepAlive] Supplier connect error: $error');
      if (_isAuthError(error)) {
        _waitingForTokenUpdate = true;
        _waitingHeartbeats = 0;
        _sendToMain({'event': 'auth:expired'});
      }
    });

    _supplierSocket!.onError((error) {
      dLog('❌ [KeepAlive] Supplier socket error: $error');
      if (_isAuthError(error)) {
        _waitingForTokenUpdate = true;
        _waitingHeartbeats = 0;
        _sendToMain({'event': 'auth:expired'});
      }
    });

    _supplierSocket!.on('order:new', (data) {
      dLog('📨 [KeepAlive] Supplier socket — order:new');
      _sendToMain({'event': 'order:new', 'data': _toSafeMap(data)});
    });

    _supplierSocket!.on('auth:expired', (_) {
      _waitingForTokenUpdate = true;
      _waitingHeartbeats = 0;
      _sendToMain({'event': 'auth:expired'});
    });

    _supplierSocket!.connect();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isAuthError(dynamic error) {
    if (error == null) return false;
    final msg = (error is Map ? (error['message'] ?? error.toString()) : error)
        .toString()
        .toLowerCase();
    return msg.contains('unauthorized') ||
        msg.contains('jwt expired') ||
        msg.contains('invalid token') ||
        msg.contains('jwt malformed') ||
        msg.contains('token_expired');
  }

  Map<String, dynamic> _toSafeMap(dynamic data) {
    if (data is Map) {
      return data.map((k, v) {
        final key = k.toString();
        if (v is Map) return MapEntry(key, _toSafeMap(v));
        if (v is List) {
          return MapEntry(
            key,
            v.map((e) => e is Map ? _toSafeMap(e) : e).toList(),
          );
        }
        return MapEntry(key, v);
      });
    }
    return {};
  }

  void _sendToMain(Map<String, dynamic> data) {
    try {
      FlutterForegroundTask.sendDataToMain(data);
    } catch (e) {
      dLog('⚠️ [KeepAlive] sendDataToMain failed: $e');
    }
  }
}

// ── Public API ─────────────────────────────────────────────────────────────────
class KeepAliveService {
  KeepAliveService._();

  /// The dedicated base URL for the supplier socket server.
  static const String supplierBaseUrl =
      'https://tawreedat.nitg-eg.com/home_supplies';

  static void initPort() {
    FlutterForegroundTask.initCommunicationPort();
  }

  static Future<void> init() async {
    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'keep_alive_channel',
        channelName: 'Connection Active',
        channelDescription: 'Keeping your connection alive in the background',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    dLog('✅ [KeepAlive] Initialized');
  }

  static Future<bool> start() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        dLog('ℹ️ [KeepAlive] Service already running');
        return true;
      }
      // Pass debug flag so background isolate knows whether to emit logs
      await FlutterForegroundTask.saveData(key: _kDebugKey, value: kDebugMode);
      dLog('🚀 [KeepAlive] Starting foreground service...');
      final result = await FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: 'مرحباً بك',
        notificationText: '',
        callback: keepAliveCallback,
      );
      if (result is ServiceRequestSuccess) {
        dLog('✅ [KeepAlive] Service started successfully');
        return true;
      }
      final error = (result as ServiceRequestFailure).error;
      dLog('❌ [KeepAlive] Service failed: ${error.runtimeType} — $error');
      return false;
    } catch (e) {
      dLog('❌ [KeepAlive] start() threw: $e');
      return false;
    }
  }

  // ── Socket commands ───────────────────────────────────────────────────────

  static Future<void> connectSocket({
    required String baseUrl,
    required String token,
    required String refreshToken,
    String? customSupplierBaseUrl,
  }) async {
    final resolvedSupplierUrl = customSupplierBaseUrl ?? supplierBaseUrl;

    // Write to storage first (for boot/replace restarts).
    await FlutterForegroundTask.saveData(key: _kAvailableKey,       value: true);
    await FlutterForegroundTask.saveData(key: _kBaseUrlKey,         value: baseUrl);
    await FlutterForegroundTask.saveData(key: _kSupplierBaseUrlKey, value: resolvedSupplierUrl);
    await FlutterForegroundTask.saveData(key: _kTokenKey,           value: token);
    await FlutterForegroundTask.saveData(key: _kRefreshTokenKey,    value: refreshToken);

    // Then send the live command to the already-running isolate.
    _sendCommand({
      'command':         'connect',
      'baseUrl':         baseUrl,
      'supplierBaseUrl': resolvedSupplierUrl,
      'token':           token,
      'refreshToken':    refreshToken,
    });
  }

  static void reconnectSocket() => _sendCommand({'command': 'reconnect'});

  static Future<void> disconnectSocket() async {
    // Storage first — boot/replace restart reads this before credentials.
    await FlutterForegroundTask.saveData(key: _kAvailableKey,       value: false);
    await FlutterForegroundTask.saveData(key: _kBaseUrlKey,         value: '');
    await FlutterForegroundTask.saveData(key: _kSupplierBaseUrlKey, value: '');
    await FlutterForegroundTask.saveData(key: _kTokenKey,           value: '');
    await FlutterForegroundTask.saveData(key: _kRefreshTokenKey,    value: '');
    // Live command after storage is written.
    _sendCommand({'command': 'disconnect'});
  }

  static void updateToken(String newAccessToken, String newRefreshToken) {
    FlutterForegroundTask.saveData(key: _kTokenKey, value: newAccessToken);
    FlutterForegroundTask.saveData(
      key: _kRefreshTokenKey,
      value: newRefreshToken,
    );
    _sendCommand({
      'command': 'updateToken',
      'token': newAccessToken,
      'refreshToken': newRefreshToken,
    });
  }

  static void emitSocketEvent(String event, dynamic payload) {
    _sendCommand({
      'command': 'socket:emit',
      'event': event,
      'payload': payload,
    });
  }

  static void emitSocketWithAck(
    String event,
    dynamic payload, {
    required String ackId,
  }) {
    _sendCommand({
      'command': 'socket:emit_with_ack',
      'event': event,
      'payload': payload,
      'ackId': ackId,
    });
  }

  // ── Location tracking ─────────────────────────────────────────────────────

  static void startLocationTracking(int orderId) {
    if (!Platform.isAndroid) return;
    _sendCommand({'command': 'tracking:start', 'orderId': orderId});
  }

  static void stopLocationTracking() {
    if (!Platform.isAndroid) return;
    _sendCommand({'command': 'tracking:stop'});
  }

  /// Persists the courier's availability flag in the task-isolate data store.
  /// This prevents autoRunOnBoot from reconnecting when the courier is offline.
  static Future<void> saveAvailability(bool isAvailable) async {
    await FlutterForegroundTask.saveData(
      key: _kAvailableKey,
      value: isAvailable,
    );
    dLog('💾 [KeepAlive] Availability saved: $isAvailable');
  }

  // ── Stop the service ──────────────────────────────────────────────────────

  static Future<void> stop() async {
    try {
      await disconnectSocket();
      final result = await FlutterForegroundTask.stopService();
      dLog('🛑 [KeepAlive] Service stop result: $result');
    } catch (e) {
      dLog('⚠️ [KeepAlive] Failed to stop: $e');
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static void _sendCommand(Map<String, dynamic> data) {
    try {
      FlutterForegroundTask.sendDataToTask(data);
    } catch (e) {
      dLog('⚠️ [KeepAlive] sendDataToTask failed: $e');
    }
  }

  static void requestLocationUpdate() {
    if (!Platform.isAndroid) return;
    _sendCommand({'command': 'location:get'});
  }
}
