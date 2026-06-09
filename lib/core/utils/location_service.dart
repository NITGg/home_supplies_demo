import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../l10n/app_localizations.dart';
import 'secure_storage_service.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();
  bool _isRequesting = false;

  // ── Default-address coordinates ───────────────────────────────────────────
  // Updated by AddressCubit whenever the address list is (re)loaded.
  // Read by data-sources (e.g. ProductRemoteDataSourceImpl) via [latLngBody].

  String? _lat;
  String? _lng;

  static const _kLat = 'default_address_lat';
  static const _kLng = 'default_address_lng';

  /// Updates the in-memory coordinates AND persists them so they survive
  /// an app restart. Pass nulls to clear (e.g. on logout).
  Future<void> update({required String? lat, required String? lng}) async {
    _lat = lat;
    _lng = lng;
    final storage = SecureStorageService();
    if (lat != null && lng != null) {
      await Future.wait([
        storage.writeValue(_kLat, lat),
        storage.writeValue(_kLng, lng),
      ]);
    } else {
      await Future.wait([
        storage.deleteValue(_kLat),
        storage.deleteValue(_kLng),
      ]);
    }
  }

  /// Restores coordinates persisted in a previous session.
  /// Call once in main() before the widget tree builds so the first
  /// product fetch already has coordinates available.
  Future<void> restoreFromStorage() async {
    final storage = SecureStorageService();
    final results = await Future.wait([
      storage.readValue(_kLat),
      storage.readValue(_kLng),
    ]);
    _lat = results[0];
    _lng = results[1];
  }

  /// Returns `{"lat": "...", "lng": "..."}` when coordinates are available,
  /// or an empty map when they are not (safe to spread into a request body).
  Map<String, String> get latLngBody {
    if (_lat == null || _lng == null) return const {};
    return {'lat': _lat!, 'lng': _lng!};
  }

  bool get hasLocation => _lat != null && _lng != null;

  // ── GPS / device location ─────────────────────────────────────────────────

  Future<Position?> getCurrentLocation({BuildContext? context}) async {
    if (_isRequesting) {
      while (_isRequesting) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        return null;
      }
    }

    _isRequesting = true;
    try {
      return await _doGetLocation(context: context);
    } finally {
      _isRequesting = false;
    }
  }

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
