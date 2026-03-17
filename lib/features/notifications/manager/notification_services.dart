import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

import '../../../main.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// Holds a payload that arrived before the navigator was ready
  /// (cold-start tap from the OS notification centre).
  static Map<String, dynamic>? pendingTapPayload;

  static Future<void> initialize() async {
    // ── Android notification channel ────────────────────────────────────────
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
      >()
          ?.createNotificationChannel(channel);

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
      >()
          ?.requestNotificationsPermission();
    }

    // ── Initialization settings ─────────────────────────────────────────────
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      // Handles taps when the app is terminated (cold start via local notif)
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapBackground,
    );
  }

  // ── Tap handler (foreground / background) ──────────────────────────────────

  static void _onNotificationTap(NotificationResponse response) {
    _processResponse(response);
  }

  @pragma('vm:entry-point')
  static void _onNotificationTapBackground(NotificationResponse response) {
    _processResponse(response);
  }

  static void _processResponse(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      handleNotificationTap(data);
    } catch (e) {
      debugPrint('⚠️ Error decoding notification payload: $e');
    }
  }

  // ── Show local notification ────────────────────────────────────────────────

  static Future<void> showNotification(
      String title,
      String body,
      Map<String, dynamic> data,
      ) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final int notificationId = _safeNotificationId(data);

      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        platformDetails,
        payload: jsonEncode(data),
      );
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  static int _safeNotificationId(Map<String, dynamic> data) {
    if (data['notificationId'] != null) {
      return data['notificationId'].toString().hashCode & 0x7fffffff;
    }
    return DateTime.now().millisecondsSinceEpoch.remainder(100000);
  }
}