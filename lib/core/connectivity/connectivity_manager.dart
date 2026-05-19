import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../utils/logger.dart';

class ConnectivityManager {
  static final ConnectivityManager _instance = ConnectivityManager._internal();

  factory ConnectivityManager() => _instance;

  ConnectivityManager._internal();

  static ConnectivityManager get instance => _instance;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicProbeTimer;

  // Probe config — hit multiple hosts so one outage doesn't false-positive
  static const List<String> _probeHosts = [
    'google.com',
    'cloudflare.com',
    '1.1.1.1',
  ];
  static const Duration _probeTimeout = Duration(seconds: 5);
  static const Duration _probeInterval = Duration(seconds: 30);

  bool _isConnected = true;

  bool get isConnected => _isConnected;

  final List<Function(bool isConnected)> _listeners = [];

  /// Initialize connectivity monitoring
  Future<void> init() async {
    // Run an immediate real internet check
    final hasInternet = await _probeInternet();
    _applyStatus(hasInternet);

    // React to network interface changes (WiFi/mobile on-off)
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onInterfaceChanged,
      onError: (error) => dLog('❌ Connectivity stream error: $error'),
    );

    // Periodically re-probe so we catch the "connected to router, no WAN" case
    _periodicProbeTimer = Timer.periodic(_probeInterval, (_) async {
      final connected = await _probeInternet();
      _applyStatus(connected);
    });

    dLog('✅ ConnectivityManager initialized (internet=${_isConnected})');
  }

  // Called whenever the network interface changes (e.g. WiFi toggled)
  Future<void> _onInterfaceChanged(List<ConnectivityResult> results) async {
    final hasInterface = results.any((r) => r != ConnectivityResult.none);

    if (!hasInterface) {
      // No interface at all → definitely offline, skip the probe
      _applyStatus(false);
    } else {
      // Interface is up, but verify actual internet reachability
      final hasInternet = await _probeInternet();
      _applyStatus(hasInternet);
    }
  }

  /// Attempts a DNS/socket lookup against multiple hosts.
  /// Returns true if at least one host resolves successfully.
  Future<bool> _probeInternet() async {
    for (final host in _probeHosts) {
      try {
        final result = await InternetAddress.lookup(host)
            .timeout(_probeTimeout);
        if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
          return true; // One success is enough
        }
      } on SocketException {
        // Network unreachable for this host, try the next
      } on TimeoutException {
        // Timeout for this host, try the next
      } catch (e) {
        dLog('⚠️ Probe error for $host: $e');
      }
    }
    return false; // All hosts failed
  }

  /// Apply a new status and notify listeners only on change
  void _applyStatus(bool hasInternet) {
    if (_isConnected == hasInternet) return;

    _isConnected = hasInternet;
    dLog('🌐 Internet ${_isConnected ? "restored ✅" : "lost ❌"}');

    for (final listener in _listeners) {
      listener(_isConnected);
    }
  }

  /// One-shot check — always does a live probe, ignores cached state
  Future<bool> checkConnection() async {
    final result = await _probeInternet();
    _applyStatus(result); // Keep internal state in sync
    return result;
  }

  /// Add connectivity listener
  void addListener(Function(bool isConnected) listener) {
    _listeners.add(listener);
  }

  /// Remove connectivity listener
  void removeListener(Function(bool isConnected) listener) {
    _listeners.remove(listener);
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicProbeTimer?.cancel();
    _listeners.clear();
  }
}