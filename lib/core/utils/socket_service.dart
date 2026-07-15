import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/core/utils/logger.dart';
import 'package:tawreedat_courier/main.dart' show rootNavigatorKey;
//courier
// ══════════════════════════════════════════════════════════════════════════════
// SocketService — bridge between the UI and the WebSocket connection.
//
// The actual socket lives in different places depending on platform:
//   • Android: inside _KeepAliveHandler (task isolate) so it survives swipes.
//              This class forwards commands and receives events via
//              FlutterForegroundTask channels.
//   • iOS:     directly in this class (main isolate), because iOS provides
//              no mechanism to keep a background Dart isolate alive.
//              The socket reconnects automatically when the app foregrounds
//              and on FCM silent push wakeups (add content-available:1 to
//              your FCM payloads from the server side).
//
// Admin socket:   _baseUrl        → /admin_apis/socket.io
// Supplier socket: _supplierBaseUrl (https://tawreedatsupplierapis.nitg-eg.com)
//
// Usage (called from HomeLayout after the profile is loaded):
//   await SocketService().start(baseUrl: '...');
//
// Reconnect on resume (called from HomeLayout.didChangeAppLifecycleState):
//   await SocketService().reconnect();
//
// Disconnect on logout:
//   SocketService().stop();
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:tawreedat_courier/core/utils/keep_alive_service.dart';
import 'package:tawreedat_courier/core/utils/secure_storage_service.dart';
import 'package:tawreedat_courier/core/utils/socket_location_utils.dart';
import 'package:tawreedat_courier/core/widgets/toast.dart';

import '../error/restart_widget.dart';
import 'location_service.dart';

// ── Connection mode ───────────────────────────────────────────────────────────
enum _ConnectionMode {
  /// Not yet connected or fully stopped.
  none,

  /// Socket lives in the KeepAlive task isolate (Android only).
  taskIsolate,

  /// Socket lives in the main isolate (iOS, or Android fallback when the
  /// foreground service fails to start).
  direct,
}

class SocketService {
  static final SocketService _instance = SocketService._internal();

  factory SocketService() => _instance;

  SocketService._internal();

  // ── State ─────────────────────────────────────────────────────────────────

  String? _baseUrl;

  /// Dedicated base URL for the supplier socket server.
  /// Defaults to [KeepAliveService.supplierBaseUrl] if not overridden.
  String _supplierBaseUrl = KeepAliveService.supplierBaseUrl;

  String? _accessToken;
  bool _isConnected = false;
  _ConnectionMode _mode = _ConnectionMode.none;

  // Auth-refresh guard.
  bool _isRefreshingToken = false;
  int _authErrorCount = 0;
  static const int _maxAuthErrors = 5;

  // Callback injected by ApiClient so HTTP and socket share the same refresh
  // lock and never issue two parallel refresh calls.
  Future<String?> Function()? _onTokenExpired;

  // Task-isolate listener handle (needed to un-register on stop).
  void Function(Object)? _taskDataCallback;

  // Direct-socket state (iOS + Android fallback).
  IO.Socket? _directSocket;
  void Function(IO.Socket)? _onNewDirectSocket;

  IO.Socket? _supplierDirectSocket;
  int _supplierDirectGen = 0;

  // Generation counter: incremented on every destroy so stale event handlers
  // from a previous socket generation are silently ignored.
  int _directGen = 0;

  // ── Stream controllers ────────────────────────────────────────────────────

  final _newOrderController =
  StreamController<Map<String, dynamic>>.broadcast();
  final _orderCancelledController =
  StreamController<Map<String, dynamic>>.broadcast();
  final _offerAcceptedController =
  StreamController<Map<String, dynamic>>.broadcast();
  final _offerRejectedController =
  StreamController<Map<String, dynamic>>.broadcast();
  final _priceReportController =
  StreamController<Map<String, dynamic>>.broadcast();
  final _orderTakenController =
  StreamController<Map<String, dynamic>>.broadcast();
  final _newOfferController =
  StreamController<Map<String, dynamic>>.broadcast();
  final _deliveryConfirmedByCustomerController =
  StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  // ── Public streams ────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>> get onNewOrderAvailable =>
      _newOrderController.stream;

  Stream<Map<String, dynamic>> get onOrderCancelled =>
      _orderCancelledController.stream;

  Stream<Map<String, dynamic>> get onOfferAccepted =>
      _offerAcceptedController.stream;

  Stream<Map<String, dynamic>> get onOfferRejected =>
      _offerRejectedController.stream;

  Stream<Map<String, dynamic>> get onPriceReportResponse =>
      _priceReportController.stream;

  Stream<Map<String, dynamic>> get onOrderTaken => _orderTakenController.stream;

  Stream<Map<String, dynamic>> get onNewOffer => _newOfferController.stream;

  Stream<Map<String, dynamic>> get onDeliveryConfirmedByCustomer =>
      _deliveryConfirmedByCustomerController.stream;

  Stream<bool> get onConnectionChanged => _connectionStateController.stream;

  // Pending ack callbacks keyed by ack ID (used in task-isolate mode).
  final Map<String, void Function(Map<String, dynamic>)> _pendingChatAcks = {};

  // Receives chat events forwarded from the task isolate.
  void Function(String event, Map<String, dynamic> data)? _chatEventDelegate;

  bool get isConnected => _isConnected;

  /// Exposes the live direct socket so other services (e.g. ChatSocketService)
  /// can borrow it instead of opening a second connection.
  /// Returns null when the socket lives in the task isolate (Android background).
  IO.Socket? get rawSocket => _directSocket;

  _ConnectionMode get connectionMode => _mode;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Injects the shared token-refresh callback from ApiClient.
  /// Must be called from ApiClient.init() before any connection is made.
  void setTokenRefreshCallback(Future<String?> Function() onRefresh) {
    _onTokenExpired = onRefresh;
  }

  void setNewSocketCallback(void Function(IO.Socket)? callback) {
    _onNewDirectSocket = callback;
  }

  void setChatEventDelegate(
      void Function(String event, Map<String, dynamic> data)? delegate,
      ) => _chatEventDelegate = delegate;

  void emitChatEvent(String event, Map<String, dynamic> payload) {
    if (_mode == _ConnectionMode.taskIsolate) {
      KeepAliveService.emitSocketEvent(event, payload);
    } else {
      _directSocket?.emit(event, payload);
    }
  }

  void emitChatWithAck(
      String event,
      Map<String, dynamic> payload, {
        required String ackId,
        required void Function(Map<String, dynamic>) onAck,
        required void Function() onError,
      }) {
    if (_mode == _ConnectionMode.taskIsolate) {
      _pendingChatAcks[ackId] = onAck;
      KeepAliveService.emitSocketWithAck(event, payload, ackId: ackId);
    } else if (_directSocket != null) {
      _directSocket!.emitWithAck(
        event,
        payload,
        ack: (rawAck) {
          if (rawAck is Map<String, dynamic>) {
            onAck(rawAck);
            return;
          }
          if (rawAck is Map) {
            onAck(Map<String, dynamic>.from(rawAck));
            return;
          }
          if (rawAck == true || rawAck == 'ok') {
            onAck({'success': true});
            return;
          }
          onError();
        },
      );
    } else {
      onError();
    }
  }

  /// Starts the socket connection using the right strategy for the current
  /// platform. Reads the token from SecureStorage automatically.
  ///
  /// [supplierBaseUrl] overrides the default supplier server URL
  /// (https://tawreedatsupplierapis.nitg-eg.com). Pass it only if you need
  /// a non-standard value; the constant in KeepAliveService is used otherwise.
  Future<void> start({required String baseUrl, String? supplierBaseUrl}) async {
    _baseUrl = baseUrl;
    _supplierBaseUrl = supplierBaseUrl ?? KeepAliveService.supplierBaseUrl;
    _accessToken = await SecureStorageService().getToken();

    if (_accessToken == null || _accessToken!.isEmpty) {
      dLog('⚠️ [SocketService] No token — aborting start');
      return;
    }

    // Register to receive events from the task isolate (no-op on iOS).
    _startListening();

    if (Platform.isAndroid) {
      await _startAndroid();
    } else {
      await _startDirect();
    }
  }

  /// Re-establishes the connection using whichever mode was set up by [start].
  /// Call this from didChangeAppLifecycleState when the app foregrounds.
  Future<void> reconnect() async {
    if (_baseUrl == null) {
      dLog('⚠️ [SocketService] reconnect() called before start() — ignored');
      return;
    }

    if (_isConnected) {
      dLog('ℹ️ [SocketService] Already connected — nothing to do');
      return;
    }

    dLog('🔄 [SocketService] Reconnecting (mode: ${_mode.name})...');

    switch (_mode) {
      case _ConnectionMode.taskIsolate:
        if (await FlutterForegroundTask.isRunningService) {
          KeepAliveService.reconnectSocket();
        } else {
          dLog(
            '⚠️ [SocketService] Foreground service not running, restarting...',
          );
          final started = await KeepAliveService.start();
          if (started && _accessToken != null) {
            final refreshToken =
                await SecureStorageService().getRefreshToken() ?? '';
            await KeepAliveService.connectSocket(
              baseUrl: _baseUrl!,
              token: _accessToken!,
              refreshToken: refreshToken,
              customSupplierBaseUrl: _supplierBaseUrl,
            );
          } else {
            await _startDirect();
          }
        }

      case _ConnectionMode.direct:
        _accessToken = await SecureStorageService().getToken();
        if (_accessToken != null && _accessToken!.isNotEmpty) {
          await _startDirect();
        }

      case _ConnectionMode.none:
        break;
    }
  }

  /// Drops the active socket connections but keeps all state intact
  /// so [reconnect] can re-establish them without calling [start] again.
  /// Used by AvailabilityCubit when the courier goes unavailable.
  Future<void> disconnectOnly() async {
    dLog('🔌 [SocketService] disconnectOnly()');

    if (_mode == _ConnectionMode.taskIsolate) {
      // The task isolate drops both sockets; the service keeps running.
      await KeepAliveService.disconnectSocket();
    } else {
      // Direct mode: destroy local socket objects.
      _destroyDirectSocket();
    }

    _isConnected = false;
    _connectionStateController.add(false);
    // Intentionally do NOT reset _mode, _baseUrl, or _accessToken.
  }

  /// Disconnects the socket and stops the foreground service.
  /// After this call, [start] must be called again to reconnect.
  Future<void> stop() async {
    dLog('🔌 [SocketService] Stopping');

    _unregisterCallback();

    if (_mode == _ConnectionMode.taskIsolate) {
      await KeepAliveService.disconnectSocket();
      await KeepAliveService.stop();
    }

    _destroyDirectSocket();

    _isConnected = false;
    _mode = _ConnectionMode.none;
    _baseUrl = null;
    _accessToken = null;
    _supplierBaseUrl = KeepAliveService.supplierBaseUrl;
    _isRefreshingToken = false;
    _authErrorCount = 0;

    _pendingChatAcks.clear();
    _chatEventDelegate = null;
  }

  /// Closes all stream controllers. Call only when the app is fully shutting
  /// down (not on logout — use [stop] instead).
  void dispose() {
    stop();
    _newOrderController.close();
    _orderCancelledController.close();
    _offerAcceptedController.close();
    _offerRejectedController.close();
    _priceReportController.close();
    _orderTakenController.close();
    _newOfferController.close();
    _deliveryConfirmedByCustomerController.close();
    _connectionStateController.close();
  }

  // ── Platform-specific connection strategies ───────────────────────────────

  Future<void> _startAndroid() async {
    await LocationService.instance.requestPermissionIfNeeded();
    final perm = await FlutterForegroundTask.checkNotificationPermission();

    if (perm != NotificationPermission.granted) {
      dLog(
        '⚠️ [SocketService] No notification permission — using direct socket',
      );
      await _startDirect();
      return;
    }

    final started = await KeepAliveService.start();

    if (started) {
      dLog('🔌 [SocketService] Connecting via task isolate...');
      _mode = _ConnectionMode.taskIsolate;
      final refreshToken = await SecureStorageService().getRefreshToken() ?? '';
      await KeepAliveService.connectSocket(
        baseUrl: _baseUrl!,
        token: _accessToken!,
        refreshToken: refreshToken,
        customSupplierBaseUrl: _supplierBaseUrl,
      );
    } else {
      dLog(
        '⚠️ [SocketService] Foreground service unavailable — direct socket fallback',
      );
      await _startDirect();
    }
  }

  Future<void> _startDirect() async {
    if (_baseUrl == null || _accessToken == null) {
      dLog('❌ [SocketService] _startDirect aborted — baseUrl or token is null');
      return;
    }
    _mode = _ConnectionMode.direct;
    await _connectDirect(
      baseUrl: _baseUrl!,
      token: _accessToken!,
      supplierBaseUrl: _supplierBaseUrl,
    );
  }

  Future<void> _connectDirect({
    required String baseUrl,
    required String token,
    required String supplierBaseUrl,
  }) async {
    _destroyDirectSocket();

    final gen = ++_directGen;
    dLog('🔌 [SocketService] Direct connect (gen $gen)...');

    _directSocket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setPath('/admin_apis/socket.io')
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .setReconnectionAttempts(-1)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(60000)
          .enableReconnection()
          .enableAutoConnect()
          .enableForceNew()
          .build(),
    );

    _directSocket!.onConnect((_) {
      if (gen != _directGen) return;
      dLog('✅ [SocketService] Direct socket connected');
      DebugToast.show('Online 🛜');
      _isConnected = true;
      _authErrorCount = 0;
      _isRefreshingToken = false;
      _connectionStateController.add(true);
      _onNewDirectSocket?.call(_directSocket!);
    });

    _directSocket!.onDisconnect((reason) {
      if (gen != _directGen) return;
      dLog('❌ [SocketService] Direct socket disconnected: $reason');
      _isConnected = false;
      _connectionStateController.add(false);
      if (reason?.toString() == 'io server disconnect') {
        _handleAuthExpired();
      }
    });

    _directSocket!.onConnectError((e) {
      if (gen != _directGen) return;
      dLog('⚠️ [SocketService] Direct connect error: $e');
      if (_isAuthError(e)) _handleAuthExpired();
    });

    _directSocket!.onError((e) {
      if (gen != _directGen) return;
      dLog('❌ [SocketService] Direct socket error: $e');
      if (_isAuthError(e)) _handleAuthExpired();
    });

    final eventMap = {
      'order:new': _newOrderController,
      'order:cancelled': _orderCancelledController,
      'offer:accepted': _offerAcceptedController,
      'offer:rejected': _offerRejectedController,
      'priceReport:response': _priceReportController,
      'order:taken': _orderTakenController,
      'offer:new': _newOfferController,
      'order:delivery_confirmed_customer': _deliveryConfirmedByCustomerController,
    };

    for (final entry in eventMap.entries) {
      _directSocket!.on(entry.key, (data) {
        if (gen != _directGen) return;
        dLog('📨 [SocketService] Direct event: ${entry.key}');
        _emit(entry.value, data);
      });
    }

    _directSocket!.on('auth:expired', (_) {
      if (gen != _directGen) return;
      _handleAuthExpired();
    });

    _directSocket!.on('courier:get_location', (_) async {
      if (gen != _directGen) return;
      final position = await LocationUtils.getCurrentPosition();
      if (position == null) return;
      _directSocket?.emit('courier:location_response', {
        'lat': position.latitude,
        'lng': position.longitude,
      });
      dLog('📍 [SocketService] courier:get_location response sent');
    });

    _directSocket!.connect();

    // ── Supplier socket ───────────────────────────────────────────────────
    await _connectSupplierDirect(
      supplierBaseUrl: supplierBaseUrl,
      token: token,
    );
  }

  Future<void> _connectSupplierDirect({
    required String supplierBaseUrl,
    required String token,
  }) async {
    if (_supplierDirectSocket != null) {
      _supplierDirectSocket!.offAny();
      _supplierDirectSocket!.disconnect();
      _supplierDirectSocket!.dispose();
      _supplierDirectSocket = null;
    }

    final gen = ++_supplierDirectGen;
    dLog(
      '🔌 [SocketService] Supplier direct connect → $supplierBaseUrl (gen $gen)...',
    );

    _supplierDirectSocket = IO.io(
      supplierBaseUrl,
      IO.OptionBuilder()
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

    _supplierDirectSocket!.onConnect((_) {
      if (gen != _supplierDirectGen) return;
      dLog('✅ [SocketService] Supplier direct socket connected');
    });

    _supplierDirectSocket!.onDisconnect((reason) {
      if (gen != _supplierDirectGen) return;
      dLog('❌ [SocketService] Supplier direct socket disconnected: $reason');
      if (reason?.toString() == 'io server disconnect') {
        _handleAuthExpired();
      }
    });

    _supplierDirectSocket!.onConnectError((e) {
      if (gen != _supplierDirectGen) return;
      dLog('⚠️ [SocketService] Supplier direct connect error: $e');
      if (_isAuthError(e)) _handleAuthExpired();
    });

    _supplierDirectSocket!.onError((e) {
      if (gen != _supplierDirectGen) return;
      dLog('❌ [SocketService] Supplier direct socket error: $e');
      if (_isAuthError(e)) _handleAuthExpired();
    });

    _supplierDirectSocket!.on('order:new', (data) {
      if (gen != _supplierDirectGen) return;
      dLog('📨 [SocketService] Supplier socket — order:new');
      _emit(_newOrderController, data);
    });

    _supplierDirectSocket!.on('auth:expired', (_) {
      if (gen != _supplierDirectGen) return;
      _handleAuthExpired();
    });

    _supplierDirectSocket!.connect();
  }

  void _destroyDirectSocket() {
    if (_directSocket != null) {
      _directSocket!.offAny();
      _directSocket!.disconnect();
      _directSocket!.dispose();
      _directSocket = null;
    }
    if (_supplierDirectSocket != null) {
      _supplierDirectSocket!.offAny();
      _supplierDirectSocket!.disconnect();
      _supplierDirectSocket!.dispose();
      _supplierDirectSocket = null;
    }
  }

  // ── Task-isolate event listener ───────────────────────────────────────────

  void _startListening() {
    if (_taskDataCallback != null) return;
    _taskDataCallback = _onTaskData;
    FlutterForegroundTask.addTaskDataCallback(_taskDataCallback!);
    dLog('👂 [SocketService] Listening to task isolate');
  }

  void _onTaskData(Object data) {
    if (data is! Map<String, dynamic>) return;

    final event = data['event'] as String?;
    if (event == null) return;

    dLog('📨 [SocketService] Task event: $event');

    switch (event) {
      case 'connection_state':
        final connected = data['connected'] == true;
        _isConnected = connected;
        _connectionStateController.add(connected);
        if (connected) {
          _isRefreshingToken = false;
          _authErrorCount = 0;
        }

      case 'auth:expired':
        _handleAuthExpired();

    // The task isolate self-refreshed while the main isolate was dead.
    // Sync tokens back into secure storage.
      case 'token_refreshed':
        _syncSelfRefreshedToken(
          newAccessToken: data['token'] as String? ?? '',
          newRefreshToken: data['refreshToken'] as String? ?? '',
        );

      case 'order:new':
        _emit(_newOrderController, data['data']);
      case 'order:cancelled':
        _emit(_orderCancelledController, data['data']);
      case 'offer:accepted':
        _emit(_offerAcceptedController, data['data']);
      case 'offer:rejected':
        _emit(_offerRejectedController, data['data']);
      case 'priceReport:response':
        _emit(_priceReportController, data['data']);
      case 'order:taken':
        _emit(_orderTakenController, data['data']);
      case 'offer:new':
        _emit(_newOfferController, data['data']);

      case 'order:delivery_confirmed_customer':
        _emit(_deliveryConfirmedByCustomerController, data['data']);

      case 'chat:new_message':
      case 'chat:user_typing':
      case 'chat:user_stopped_typing':
      case 'chat:message_read':
        final chatPayload = data['data'];
        final chatMap = chatPayload is Map<String, dynamic>
            ? chatPayload
            : chatPayload is Map
            ? Map<String, dynamic>.from(chatPayload)
            : <String, dynamic>{};
        _chatEventDelegate?.call(event, chatMap);

      case 'socket:ack':
        final ackId = data['ackId'] as String? ?? '';
        final ackData = data['data'];
        final ackMap = ackData is Map<String, dynamic>
            ? ackData
            : ackData is Map
            ? Map<String, dynamic>.from(ackData)
            : <String, dynamic>{'success': true};
        _pendingChatAcks.remove(ackId)?.call(ackMap);
    }
  }

  Future<void> _syncSelfRefreshedToken({
    required String newAccessToken,
    required String newRefreshToken,
  }) async {
    if (newAccessToken.isEmpty) return;
    dLog('🔑 [SocketService] Syncing self-refreshed token from task isolate');
    _accessToken = newAccessToken;
    await SecureStorageService().saveToken(newAccessToken);
    if (newRefreshToken.isNotEmpty) {
      await SecureStorageService().saveRefreshToken(newRefreshToken);
    }
  }

  void _emit(
      StreamController<Map<String, dynamic>> controller,
      dynamic payload,
      ) {
    if (payload is Map<String, dynamic>) {
      controller.add(payload);
    } else if (payload is Map) {
      controller.add(Map<String, dynamic>.from(payload));
    } else {
      dLog('⚠️ [SocketService] Unexpected payload type: ${payload.runtimeType}');
    }
  }

  // ── Auth refresh ──────────────────────────────────────────────────────────

  Future<void> _handleAuthExpired() async {
    if (_isRefreshingToken) {
      dLog('🔁 [SocketService] Refresh already in progress — skipping');
      return;
    }

    _authErrorCount++;
    if (_authErrorCount > _maxAuthErrors) {
      dLog('🚫 [SocketService] Max auth errors reached — restarting app');
      _authErrorCount = 0;
      _isRefreshingToken = false;
      await stop();
      RestartWidget.restartApp();
      return;
    }

    if (_onTokenExpired == null) {
      dLog('⚠️ [SocketService] No token-refresh callback registered');
      return;
    }

    _isRefreshingToken = true;
    dLog(
      '🔑 [SocketService] Refreshing token (attempt $_authErrorCount/$_maxAuthErrors)...',
    );

    try {
      final newToken = await _onTokenExpired!();

      if (newToken == null || newToken.isEmpty) {
        dLog('❌ [SocketService] Refresh returned null — session ended');
        await stop();
        final context = rootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          GoRouter.of(context).go('/auth/login');
        }
        return;
      }

      if (newToken == _accessToken) {
        dLog('⚠️ [SocketService] Token unchanged — retrying in 3 s');
        await Future.delayed(const Duration(seconds: 3));
        _isRefreshingToken = false;
        _handleAuthExpired();
        return;
      }

      _accessToken = newToken;
      _authErrorCount = 0;
      dLog('✅ [SocketService] Token refreshed');

      final newRefreshToken =
          await SecureStorageService().getRefreshToken() ?? '';

      if (_mode == _ConnectionMode.taskIsolate) {
        KeepAliveService.updateToken(newToken, newRefreshToken);
      } else if (_mode == _ConnectionMode.direct) {
        await _connectDirect(
          baseUrl: _baseUrl!,
          token: newToken,
          supplierBaseUrl: _supplierBaseUrl,
        );
      }
    } catch (e) {
      dLog('❌ [SocketService] Token refresh threw: $e');
      _authErrorCount = 0;
      await stop();
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        GoRouter.of(context).go('/auth/login');
      }
    } finally {
      _isRefreshingToken = false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isAuthError(dynamic error) {
    if (error == null) return false;
    final msg =
    (error is Map
        ? (error['message'] ?? error.toString())
        : error.toString())
        .toLowerCase();
    return msg.contains('unauthorized') ||
        msg.contains('jwt expired') ||
        msg.contains('invalid token') ||
        msg.contains('jwt malformed') ||
        msg.contains('token_expired');
  }

  void _unregisterCallback() {
    if (_taskDataCallback != null) {
      FlutterForegroundTask.removeTaskDataCallback(_taskDataCallback!);
      _taskDataCallback = null;
    }
  }

  Future<bool> requestLocationUpdate() async {
    if (_mode == _ConnectionMode.taskIsolate) {
      KeepAliveService.requestLocationUpdate();
      return true;
    } else if (_directSocket != null) {
      final position = await LocationUtils.getCurrentPosition();
      if (position == null) return false;

      final completer = Completer<bool>();

      _directSocket!.emitWithAck(
        'courier:location_response',
        {'lat': position.latitude, 'lng': position.longitude},
        ack: (response) {
          final success = response is Map && response['success'] == true;
          completer.complete(success);
        },
      );

      return completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
    }
    return false;
  }
}