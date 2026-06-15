import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/safe_emit_mixin.dart';
import 'notification_states.dart';

class NotificationsCubit extends Cubit<NotificationsState> with SafeEmitMixin<NotificationsState> {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

  NotificationsCubit(this.userId) : super(NotificationsInitial());

  void loadNotifications() {
    if (isClosed) return;

    safeEmit(NotificationsLoading());

    _notificationsSubscription?.cancel();
    _notificationsSubscription = _firestore
        .collection('Notifications')
        .where('user_id', isEqualTo: int.tryParse(userId))
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
        if (!isClosed) {
          final unreadCount = snapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data != null && !(data['is_read'] ?? false);
          }).length;

          safeEmit(NotificationsLoaded(snapshot.docs, unreadCount));
        }
      },
      onError: (error) {
        if (!isClosed) {
          safeEmit(NotificationsError('Error loading notifications'));
        }
      },
    );
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('Notifications').doc(notificationId).update({
        'is_read': true,
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final notificationsQuery = await _firestore
          .collection('Notifications')
          .where('user_id', isEqualTo: int.tryParse(userId))
          .where('is_read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in notificationsQuery.docs) {
        batch.update(doc.reference, {'is_read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('Notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      final notificationsQuery = await _firestore
          .collection('Notifications')
          .where('user_id', isEqualTo: int.tryParse(userId))
          .get();

      final batch = _firestore.batch();
      for (var doc in notificationsQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  @override
  Future<void> close() {
    _notificationsSubscription?.cancel();
    return super.close();
  }
}