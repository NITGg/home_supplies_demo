import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── States ────────────────────────────────────────────────────────────────────

abstract class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object?> get props => [];
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsLoaded extends NotificationsState {
  final List<DocumentSnapshot> notifications;
  final int unreadCount;
  const NotificationsLoaded(this.notifications, this.unreadCount);

  @override
  List<Object?> get props => [notifications, unreadCount];
}

class NotificationsError extends NotificationsState {
  final String message;
  const NotificationsError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class NotificationsCubit extends Cubit<NotificationsState> {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

  NotificationsCubit(this.userId) : super(NotificationsInitial());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed.
  @override
  void emit(NotificationsState state) {
    if (!isClosed) super.emit(state);
  }

  void loadNotifications() {
    if (isClosed) return;
    emit(NotificationsLoading());
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
          emit(NotificationsLoaded(snapshot.docs, unreadCount));
        }
      },
      onError: (_) {
        if (!isClosed) {
          emit(NotificationsError('Error loading notifications'));
        }
      },
    );
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('Notifications')
          .doc(notificationId)
          .update({'is_read': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final query = await _firestore
          .collection('Notifications')
          .where('user_id', isEqualTo: int.tryParse(userId))
          .where('is_read', isEqualTo: false)
          .get();
      final batch = _firestore.batch();
      for (var doc in query.docs) {
        batch.update(doc.reference, {'is_read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('Notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      final query = await _firestore
          .collection('Notifications')
          .where('user_id', isEqualTo: int.tryParse(userId))
          .get();
      final batch = _firestore.batch();
      for (var doc in query.docs) {
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