import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/api_client.dart';
import '../../../core/utils/logger.dart';
import '../data/notification_settings_model.dart';

// ── States ────────────────────────────────────────────────────────────────────

abstract class NotificationSettingsState {}

class NotificationSettingsInitial extends NotificationSettingsState {}

class NotificationSettingsLoading extends NotificationSettingsState {}

class NotificationSettingsLoaded extends NotificationSettingsState {
  final NotificationSettings settings;
  NotificationSettingsLoaded(this.settings);
}

class NotificationSettingsUpdating extends NotificationSettingsState {
  final NotificationSettings settings;
  NotificationSettingsUpdating(this.settings);
}

class NotificationSettingsError extends NotificationSettingsState {
  final String message;
  NotificationSettingsError(this.message);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class NotificationSettingsCubit extends Cubit<NotificationSettingsState> {
  final Dio _dio;

  NotificationSettingsCubit({Dio? dio})
      : _dio = dio ?? ApiClient.instance.dio,
        super(NotificationSettingsInitial());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed.
  @override
  void emit(NotificationSettingsState state) {
    if (!isClosed) super.emit(state);
  }

  Future<void> loadSettings() async {
    emit(NotificationSettingsLoading());
    try {
      final response = await _dio.get(
        '/notification/get-settings',
      );
      final settings = NotificationSettings.fromJson(response.data['data']);
      emit(NotificationSettingsLoaded(settings));
    } catch (e) {
      dLog('Error loading notification settings: $e');
      emit(NotificationSettingsError('Failed to load settings'));
    }
  }

  Future<void> updateSetting(NotificationSettings updated) async {
    // Optimistic update — reflect toggle immediately
    emit(NotificationSettingsUpdating(updated));
    try {
      await _dio.patch(
        '/notification/update-settings',
        data: updated.toJson(),
      );
      emit(NotificationSettingsLoaded(updated));
    } catch (e) {
      dLog('Error updating notification settings: $e');
      emit(NotificationSettingsError('Failed to update settings'));
    }
  }
}