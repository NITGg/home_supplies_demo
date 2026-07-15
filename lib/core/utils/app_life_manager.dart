import 'package:tawreedat_courier/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'secure_storage_service.dart';

class AppLifecycleManager extends WidgetsBindingObserver {
  final VoidCallback onLockRequired;
  final SecureStorageService _storage = SecureStorageService();

  DateTime? _backgroundTime;
  static const Duration _biometricTimeout = Duration(minutes: 2);

  AppLifecycleManager({required this.onLockRequired}) {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _backgroundTime = DateTime.now();
        dLog('AppLifecycleManager: backgrounded at $_backgroundTime');
      case AppLifecycleState.resumed:
        dLog('AppLifecycleManager: resumed');
        _handleAppResume();
      default:
        break;
    }
  }

  Future<void> _handleAppResume() async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      dLog('AppLifecycleManager: no token — skipping');
      return;
    }

    if (_backgroundTime != null) {
      final elapsed = DateTime.now().difference(_backgroundTime!);
      if (elapsed < _biometricTimeout) {
        dLog(
          'AppLifecycleManager: only ${elapsed.inSeconds}s in background — skipping',
        );
        return;
      }
    }

    dLog('AppLifecycleManager: timeout exceeded — locking');
    onLockRequired();
  }
}