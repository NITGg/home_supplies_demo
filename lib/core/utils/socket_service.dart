import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class SocketService {
  static final SocketService _instance = SocketService._internal();

  factory SocketService() => _instance;

  SocketService._internal();

  IO.Socket? _socket;

  // Stream controllers for order/offer events
  final _newOfferController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _priceReportController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderCancelledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderCollectedController =
      StreamController<Map<String, dynamic>>.broadcast();

  final _courierLocationController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Track which orders we're currently in rooms for
  final Set<int> _activeOrderRooms = {};

  // Public streams
  Stream<Map<String, dynamic>> get onNewOffer => _newOfferController.stream;

  Stream<Map<String, dynamic>> get onPriceReport =>
      _priceReportController.stream;

  Stream<Map<String, dynamic>> get onOrderCancelled =>
      _orderCancelledController.stream;

  Stream<Map<String, dynamic>> get onOrderCollected =>
      _orderCollectedController.stream;

  Stream<Map<String, dynamic>> get onCourierLocation =>
      _courierLocationController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Exposes the raw socket so the chat module can attach its own listeners.
  /// Returns null if the socket has not been connected yet.
  IO.Socket? get rawSocket => _socket;

  // ================= CONNECT =================
  void connect({required String baseUrl, required String accessToken}) {
    if (_socket?.connected ?? false) {
      log('✅ Socket already connected');
      return;
    }

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setPath('/courier_apis/socket.io')
          .setTransports(['websocket'])
          .setAuth({'accessToken': "Bearer $accessToken"})
          .enableAutoConnect()
          .build(),
    );

    _socket!.connect();
    _setupListeners();
  }

  // ================= SETUP LISTENERS (called once) =================
  void _setupListeners() {
    _socket!.onConnect((_) {
      log('✅ Socket Connected: ${_socket!.id}');
      // Rejoin all active order rooms after reconnection
      for (final orderId in _activeOrderRooms) {
        _socket!.emit('join:order', {'orderId': orderId});
        log('🔗 Re-joined order room: $orderId');
      }
    });

    _socket!.onDisconnect((_) {
      log('❌ Socket Disconnected');
    });

    _socket!.onConnectError((e) {
      log('⚠️ Socket Connection Error: $e');
    });

    _socket!.on('order:collected', (data) {
      log('📦 ORDER COLLECTED: $data');
      if (data is Map<String, dynamic>) {
        _orderCollectedController.add(data);
      }
    });

    _socket!.on('offer:new', (data) {
      log('📦 NEW OFFER raw socket event — data: $data');
      log('📦 controller.hasListener: ${_newOfferController.hasListener}');
      if (data is Map<String, dynamic>) {
        _newOfferController.add(data);
        log('📦 added to controller');
      }
    });

    _socket!.on('order:price_report', (data) {
      log('💰 NEW PRICE REPORT: $data');
      if (data is Map<String, dynamic>) {
        _priceReportController.add(data);
      }
    });

    _socket!.on('order:cancelledUnavailable', (data) {
      log('🚫 ORDER CANCELLED (UNAVAILABLE): $data');
      if (data is Map<String, dynamic>) {
        _orderCancelledController.add({...data, 'reason': 'unavailable'});
      }
    });

    _socket!.on('order:cancelledOther', (data) {
      log('🚫 ORDER CANCELLED (OTHER): $data');
      if (data is Map<String, dynamic>) {
        _orderCancelledController.add({...data, 'reason': 'other'});
      }
    });

    _socket!.on('order:courier_location', (data) {
      log('🗺️ COURIER LOCATION: $data');
      if (data is Map<String, dynamic>) {
        _courierLocationController.add(data);
      }
    });
  }

  // ================= JOIN ORDER =================
  void joinOrder(int orderId) {
    if (!isConnected) {
      log('⚠️ Cannot join order $orderId - socket not connected');
      return;
    }

    if (_activeOrderRooms.contains(orderId)) {
      log('ℹ️ Already in order room: $orderId');
      return;
    }

    _socket!.emit('join:order', {'orderId': orderId});
    _activeOrderRooms.add(orderId);
    log('🔗 Joined order room: $orderId');
  }

  // ================= LEAVE ORDER =================
  void leaveOrder(int orderId) {
    if (!_activeOrderRooms.contains(orderId)) return;

    _socket?.emit('leave:order', {'orderId': orderId});
    _activeOrderRooms.remove(orderId);
    log('🔓 Left order room: $orderId');
  }

  // ================= LEAVE ALL INACTIVE ORDERS =================
  void leaveInactiveOrders(List<int> activeOrderIds) {
    final toRemove = _activeOrderRooms
        .where((id) => !activeOrderIds.contains(id))
        .toList();

    for (final orderId in toRemove) {
      leaveOrder(orderId);
    }
  }

  // ================= DISCONNECT =================
  void disconnect() {
    _activeOrderRooms.clear();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    log('🔌 Socket disconnected and disposed');
  }

  // ================= DISPOSE STREAMS =================
  void dispose() {
    disconnect();
    _newOfferController.close();
    _priceReportController.close();
    _orderCancelledController.close();
    _orderCollectedController.close();
    _courierLocationController.close();
  }
}
