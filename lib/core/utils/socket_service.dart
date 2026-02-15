import 'dart:developer';

import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();

  factory SocketService() => _instance;

  SocketService._internal();

  IO.Socket? _socket;

  IO.Socket get socket => _socket!;

  // ================= CONNECT =================
  void connect({required String baseUrl, required String accessToken}) {
    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setPath('/courier_apis/socket.io')
          .setTransports(['websocket']) // Important
          .setAuth({
            'accessToken': "Bearer $accessToken", // Matches backend
          })
          .enableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _listen();
  }

  // ================= LISTEN =================
  void _listen() {
    _socket!.onConnect((_) {
      print('Socket Connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      print('Socket Disconnected');
    });

    _socket!.onConnectError((e) {
      print('Socket Error: $e');
    });

    // 🔔 New offer available on your order
    _socket!.on('offer:new', (data) {
      log('📦 NEW OFFER: $data');

    });
    // 🔔 New price_report available on your order
    _socket!.on('order:price_report', (data) {
      log('📦 NEW price_report: $data');
    });
    // 🔔 New cancelledUnavailable available on your order
    _socket!.on('order:cancelledUnavailable', (data) {
      log('📦 NEW cancelledUnavailable: $data');
    });
    // 🔔 New order:cancelledOther available on your order
    _socket!.on('order:cancelledOther', (data) {
      log('📦 NEW order:cancelledOther: $data');
    });
  }

  // ================= JOIN ORDER =================
  void joinOrder(int orderId) {
    _socket?.emit('join:order', {'orderId': orderId});
  }

  // ================= LEAVE ORDER =================
  void leaveOrder(int orderId) {
    _socket?.emit('leave:order', {'orderId': orderId});
  }

  // ================= DISCONNECT =================
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
