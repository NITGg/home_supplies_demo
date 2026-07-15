import 'dart:io';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/keep_alive_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/secure_storage_service.dart';
import '../../../../core/utils/socket_service.dart';

enum AvailabilityStatus { available, unavailable, loading }

class AvailabilityState {
  final AvailabilityStatus status;
  final String? blockedReason;

  const AvailabilityState({required this.status, this.blockedReason});

  bool get isAvailable => status == AvailabilityStatus.available;
  bool get isLoading => status == AvailabilityStatus.loading;

  AvailabilityState copyWith({
    AvailabilityStatus? status,
    String? blockedReason,
  }) => AvailabilityState(
    status: status ?? this.status,
    blockedReason: blockedReason,
  );
}

class AvailabilityCubit extends Cubit<AvailabilityState> {
  AvailabilityCubit()
      : super(const AvailabilityState(status: AvailabilityStatus.available));

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed.
  @override
  void emit(AvailabilityState state) {
    if (!isClosed) super.emit(state);
  }

  static const String _baseUrl = 'https://tawreedat.nitg-eg.com';

  /// Called once after the profile is ready.
  /// Reads persisted availability and connects or stays disconnected.
  Future<void> initialize({VoidCallback? onUnavailable}) async {
    emit(state.copyWith(status: AvailabilityStatus.loading));

    final isAvailable = await SecureStorageService().getAvailability();

    if (isAvailable) {
      await _connect();
      if (!isClosed) {
        emit(const AvailabilityState(status: AvailabilityStatus.available));
      }
    } else {
      // Kill any socket that survived a previous session (boot/replace).
      await _disconnectSockets();
      onUnavailable?.call();
      if (!isClosed) {
        emit(const AvailabilityState(status: AvailabilityStatus.unavailable));
      }
      dLog('ℹ️ [Availability] Courier is offline — sockets stopped');
    }
  }

  Future<void> toggle({
    required bool hasActiveOrders,
    VoidCallback? onGoingUnavailable,
    VoidCallback? onGoingAvailable,
  }) async {
    if (state.isLoading) return;

    final goingUnavailable = state.isAvailable;

    if (goingUnavailable && hasActiveOrders) {
      emit(state.copyWith(
        status: AvailabilityStatus.available,
        blockedReason: 'لديك طلب نشط. يرجى إنهاء الطلب قبل تعطيل التوفر.',
      ));
      await Future.delayed(const Duration(milliseconds: 100));
      emit(const AvailabilityState(status: AvailabilityStatus.available));
      return;
    }

    emit(state.copyWith(status: AvailabilityStatus.loading));

    if (goingUnavailable) {
      onGoingUnavailable?.call();
      await _disconnectSockets();
      await SecureStorageService().saveAvailability(false);
      if (!isClosed) {
        emit(const AvailabilityState(status: AvailabilityStatus.unavailable));
      }
    } else {
      onGoingAvailable?.call();
      await _connect();
      await SecureStorageService().saveAvailability(true);
      if (!isClosed) {
        emit(const AvailabilityState(status: AvailabilityStatus.available));
      }
    }
  }

  /// Called from HomeLayout on app resume.
  Future<void> reconnectIfAvailable() async {
    if (!state.isAvailable) {
      dLog('ℹ️ [Availability] App resumed — courier unavailable, sockets stay off');
      return;
    }
    dLog('🔄 [Availability] App resumed — reconnecting sockets');
    await SocketService().reconnect();
  }

  /// Force-sets to available — called from the reminder sheet.
  Future<void> setAvailable() async {
    if (state.isAvailable) return;
    emit(state.copyWith(status: AvailabilityStatus.loading));
    await _connect();
    await SecureStorageService().saveAvailability(true);
    if (!isClosed) {
      emit(const AvailabilityState(status: AvailabilityStatus.available));
    }
  }

  /// Resets on logout — clears sockets and marks available for next login.
  Future<void> resetForLogout() async {
    await _disconnectSockets();
    // Stop the foreground service entirely on logout (user is leaving).
    if (Platform.isAndroid) await KeepAliveService.stop();
    await SecureStorageService().saveAvailability(true);
    emit(const AvailabilityState(status: AvailabilityStatus.available));
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Starts both the admin socket and the supplier socket.
  /// On Android this goes through the foreground service (task isolate).
  /// On iOS it uses direct sockets in the main isolate.
  Future<void> _connect() async {
    try {
      await SocketService().start(baseUrl: _baseUrl);
      dLog('✅ [Availability] Sockets started');
    } catch (e) {
      dLog('❌ [Availability] Failed to start sockets: $e');
    }
  }

  /// Disconnects both the admin and supplier sockets WITHOUT stopping
  /// the foreground service. The service stays alive so it can reconnect
  /// quickly when the courier goes available again, and the OS notification
  /// doesn't flicker.
  Future<void> _disconnectSockets() async {
    try {
      if (Platform.isAndroid) {
        // Tell the task isolate to drop both sockets but keep running.
        await KeepAliveService.disconnectSocket();
        // Persist the unavailable flag so autoRunOnBoot doesn't reconnect.
        await KeepAliveService.saveAvailability(false);
      } else {
        // iOS: destroy the direct sockets in the main isolate.
        await SocketService().disconnectOnly();
      }
      dLog('✅ [Availability] Sockets disconnected (service kept alive)');
    } catch (e) {
      dLog('❌ [Availability] Failed to disconnect sockets: $e');
    }
  }
}