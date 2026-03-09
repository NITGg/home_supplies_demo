import 'package:cloud_firestore/cloud_firestore.dart';

abstract class NotificationsState {}

class NotificationsInitial extends NotificationsState {}

class NotificationsLoading extends NotificationsState {}

class NotificationsLoaded extends NotificationsState {
  final List<DocumentSnapshot> notifications;
  final int unreadCount;

  NotificationsLoaded(this.notifications, this.unreadCount);
}

class NotificationsError extends NotificationsState {
  final String message;

  NotificationsError(this.message);
}