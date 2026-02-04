import 'dart:async';
import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityManager {
  static final ConnectivityManager _instance = ConnectivityManager._internal();

  factory ConnectivityManager() => _instance;

  ConnectivityManager._internal();

  static ConnectivityManager get instance => _instance;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Current connectivity status
  bool _isConnected = true;

  bool get isConnected => _isConnected;

  // Callbacks for connectivity changes
  final List<Function(bool isConnected)> _listeners = [];

  /// Initialize connectivity monitoring
  Future<void> init() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) {
        log('❌ Connectivity error: $error');
      },
    );

    log('✅ ConnectivityManager initialized');
  }

  /// Update connection status
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (_isConnected != hasConnection) {
      _isConnected = hasConnection;
      log(
        '🌐 Connectivity changed: ${_isConnected ? "Connected" : "Disconnected"}',
      );

      // Notify all listeners
      for (var listener in _listeners) {
        listener(_isConnected);
      }
    }
  }

  /// Add connectivity listener
  void addListener(Function(bool isConnected) listener) {
    _listeners.add(listener);
  }

  /// Remove connectivity listener
  void removeListener(Function(bool isConnected) listener) {
    _listeners.remove(listener);
  }

  /// Check if currently connected
  Future<bool> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _listeners.clear();
  }
}
