import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'biometric_auth_service.dart';
import 'secure_storage_service.dart';

class AppLifecycleManager extends WidgetsBindingObserver {
  final BuildContext context;
  final BiometricAuthService _biometricService = BiometricAuthService();
  final SecureStorageService _storage = SecureStorageService();

  DateTime? _backgroundTime;
  static const Duration _biometricTimeout = Duration(minutes: 2);
  bool _biometricChecking = false;

  AppLifecycleManager(this.context) {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      // App went to background
        _backgroundTime = DateTime.now();
        log('AppLifecycleManager: App went to background at $_backgroundTime');
        break;

      case AppLifecycleState.resumed:
      // App came to foreground
        log('AppLifecycleManager: App resumed from background');
        await _handleAppResume();
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      // App is being closed or hidden
        break;
    }
  }

  Future<void> _handleAppResume() async {
    // Prevent multiple simultaneous biometric checks
    if (_biometricChecking) {
      log('AppLifecycleManager: Biometric check already in progress, skipping');
      return;
    }

    // Check if we need biometric authentication
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      log('AppLifecycleManager: No token, skipping biometric check');
      return;
    }

    // Check if enough time has passed
    if (_backgroundTime != null) {
      final timeDiff = DateTime.now().difference(_backgroundTime!);
      if (timeDiff < _biometricTimeout) {
        log('AppLifecycleManager: App was only in background for ${timeDiff.inSeconds}s, skipping biometric');
        return;
      }
    }

    _biometricChecking = true;
    log('AppLifecycleManager: Starting biometric verification');

    try {
      final success = await BiometricManager().verifyBiometric(context: context);

      if (!success) {
        log('AppLifecycleManager: Biometric failed, logging out');
        await SecureStorageService().clearAll();

        // Use addPostFrameCallback to ensure navigation happens after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/auth/login');
          }
        });
      } else {
        log('AppLifecycleManager: Biometric verification successful');
      }
    } catch (e) {
      log('AppLifecycleManager: Error during biometric check: $e');
    } finally {
      _biometricChecking = false;
    }
  }
}

/// Extension to easily add lifecycle manager to widgets
extension AppLifecycleExtension on State {
  AppLifecycleManager createLifecycleManager() {
    return AppLifecycleManager(context);
  }
}