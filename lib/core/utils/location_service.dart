import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:tawreedat_courier/l10n/app_localizations.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();
  bool _isRequesting = false; // ← ADD

  Future<Position?> getCurrentLocation({BuildContext? context}) async {
    // ── Guard against concurrent calls ──────────────────────────
    if (_isRequesting) {
      // Wait for the in-flight request to finish, then just get position
      while (_isRequesting) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // By now permission is resolved — just get position directly
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        return null;
      }
    }

    _isRequesting = true; // ← LOCK
    try {
      return await _doGetLocation(context: context);
    } finally {
      _isRequesting = false; // ← always release
    }
  }

  // Rename your existing while(true) body into this private method
  Future<Position?> _doGetLocation({BuildContext? context}) async {
    while (true) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context == null || !context.mounted) return null;
        final l10n = AppLocalizations.of(context)!;
        final shouldOpen = await _showDialog(
          context: context,
          title: l10n.locationServicesDisabledTitle,
          message: l10n.locationServicesDisabledMessage,
          confirmText: l10n.openSettings,
        );
        if (!shouldOpen) return null;
        await Geolocator.openLocationSettings();
        await _waitForAppResume();
        continue;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context == null || !context.mounted) return null;
          final l10n = AppLocalizations.of(context)!;
          final retry = await _showDialog(
            context: context,
            title: l10n.locationPermissionDeniedTitle,
            message: l10n.locationPermissionDeniedMessage,
            confirmText: l10n.tryAgain,
          );
          if (!retry) return null;
          continue;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (context == null || !context.mounted) return null;
        final l10n = AppLocalizations.of(context)!;
        final openSettings = await _showDialog(
          context: context,
          title: l10n.locationPermissionPermanentlyDeniedTitle,
          message: l10n.locationPermissionPermanentlyDeniedMessage,
          confirmText: l10n.openAppSettings,
        );
        if (!openSettings) return null;
        await ph.openAppSettings();
        await _waitForAppResume();
        continue;
      }

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (_) {
        try {
          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          );
        } catch (_) {
          return null;
        }
      }
    }
  }

  /// Call once at app start — silently requests permission if not yet granted.
  /// Does NOT show any dialog or get position, just warms up the permission.
  Future<void> requestPermissionIfNeeded() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }


  Future<Position?> getLastKnownOrCurrent({BuildContext? context}) async {
    // Returns in ~0ms from OS cache
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      // Silently refresh in background for next call
      unawaited(getCurrentLocation(context: context));
      return last;
    }
    // First ever launch: no choice but to wait
    return getCurrentLocation(context: context);
  }

  /// Suspends execution until the app returns to the foreground.
  Future<void> _waitForAppResume() async {
    final completer = Completer<void>();

    late final _LifecycleObserver observer;
    observer = _LifecycleObserver(
      onResumed: () {
        WidgetsBinding.instance.removeObserver(observer);
        if (!completer.isCompleted) completer.complete();
      },
    );

    WidgetsBinding.instance.addObserver(observer);
    await completer.future;
  }

  Future<bool> _showDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = l10n.localeName == 'ar';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  Future<bool> isLocationServiceEnabled() async =>
      Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() async =>
      Geolocator.checkPermission();

  Future<void> openLocationSettings() async =>
      Geolocator.openLocationSettings();

  Future<void> openAppSettings() async => ph.openAppSettings();
}

/// Listens for app lifecycle changes and fires [onResumed] once.
class _LifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResumed;

  _LifecycleObserver({required this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}

