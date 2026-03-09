import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/style/app_colors.dart';
import '../../core/widgets/loading_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

// Cubit State
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

// Cubit
class NotificationsCubit extends Cubit<NotificationsState> {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

  NotificationsCubit(this.userId) : super(NotificationsInitial());

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
          onError: (error) {
            if (!isClosed) {
              emit(NotificationsError('Error loading notifications'));
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

// Show Notifications Dialog Function
void showNotificationsDialog(BuildContext context, String userId) {
  shouldShowNotificationDialog = false;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Notifications",
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation1, animation2) {
      // Return an empty container because transitionBuilder handles the dialog
      return const SizedBox.shrink();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );

      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3), // from slightly above
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 60,
            ),
            child: NotificationsDialog(userId: userId), // your widget
          ),
        ),
      );
    },
  );
}

// Notifications Dialog Widget
class NotificationsDialog extends StatelessWidget {
  final String userId;

  const NotificationsDialog({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationsCubit(userId)..loadNotifications(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: BlocBuilder<NotificationsCubit, NotificationsState>(
                builder: (context, state) {
                  final hasUnread =
                      state is NotificationsLoaded && state.unreadCount > 0;
                  final hasNotifications =
                      state is NotificationsLoaded &&
                      state.notifications.isNotEmpty;

                  return Row(
                    children: [
                      if (hasUnread)
                        Lottie.asset(
                          'assets/animation_json/notification.json',
                          width: 40,
                          height: 40,
                        ),
                      Text(
                        AppLocalizations.of(context)!.notifications,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      // Mark All As Read Button
                      IconButton(
                        onPressed: hasUnread
                            ? () async {
                                await context
                                    .read<NotificationsCubit>()
                                    .markAllAsRead();
                              }
                            : null,
                        icon: Icon(
                          Icons.done_all,
                          color: hasUnread
                              ? AppColors.kPrimaryColor
                              : Colors.grey[300],
                        ),
                        tooltip: 'Mark all as read',
                      ),
                      // Clear All Button
                      IconButton(
                        onPressed: hasNotifications
                            ? () async {
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  await context
                                      .read<NotificationsCubit>()
                                      .clearAllNotifications();
                                }
                              }
                            : null,
                        icon: Icon(
                          Icons.delete_sweep,
                          color: hasNotifications
                              ? AppColors.kPrimaryColor
                              : Colors.grey[300],
                        ),
                        tooltip: 'Clear all',
                      ),
                      // Close Button
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.grey),
                        tooltip: 'Close',
                      ),
                    ],
                  );
                },
              ),
            ),

            // Notifications List
            Expanded(
              child: BlocBuilder<NotificationsCubit, NotificationsState>(
                builder: (context, state) {
                  if (state is NotificationsLoading) {
                    return const Center(child: LoadingScreen(isOne: true));
                  }

                  if (state is NotificationsError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is NotificationsLoaded) {
                    if (state.notifications.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                          ],
                        ),
                      );
                    }
                    final isArabic =
                        Localizations.localeOf(context).languageCode == 'ar';

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.notifications.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notification = state.notifications[index];
                        final data =
                            notification.data() as Map<String, dynamic>?;

                        if (data == null) return const SizedBox.shrink();

                        return NotificationCard(
                          notificationId: notification.id,
                          isRead: data['is_read'] ?? false,
                          title: isArabic
                              ? data['title_ar']
                              : data['title'] ?? 'No Title',
                          description: isArabic
                              ? data['desc_ar']
                              : data['desc'] ?? '',
                          timestamp: data['created_at'] as Timestamp?,
                          onTap: () {
                            // TODO: Add navigation logic here
                            Navigator.of(context).pop();
                            if (context.mounted) {
                              context.read<NotificationsCubit>().markAsRead(
                                notification.id,
                              );
                              switch (data['data']['navigate']) {
                                case 'orders':
                                  context.push('/my-orders', extra: userId);
                                  break;
                                default:
                              }
                            }
                          },
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Notification Card Widget
class NotificationCard extends StatelessWidget {
  final String notificationId;
  final bool isRead;
  final String title;
  final String description;
  final Timestamp? timestamp;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notificationId,
    required this.isRead,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notificationId),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Swipe left: Delete
          await context.read<NotificationsCubit>().deleteNotification(
            notificationId,
          );
          return true;
        } else if (direction == DismissDirection.startToEnd) {
          // Swipe right: Mark as read
          if (!isRead) {
            await context.read<NotificationsCubit>().markAsRead(notificationId);
          }
          return false;
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppColors.kPrimaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Icon(Icons.done, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Icon(
                Icons.clear_all_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead
                  ? Colors.grey[200]!
                  : Colors.orange.withOpacity(0.3),
              width: isRead ? 1 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isRead
                    ? Colors.black.withOpacity(0.03)
                    : Colors.orange.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // // Icon indicator
                // Container(
                //   width: 40,
                //   height: 40,
                //   decoration: BoxDecoration(
                //     color: isRead
                //         ? Colors.grey[100]
                //         : Colors.orange.withOpacity(0.1),
                //     shape: BoxShape.circle,
                //   ),
                //   child: Icon(
                //     Icons.notifications,
                //     color: isRead ? Colors.grey[400] : Colors.orange,
                //     size: 20,
                //   ),
                // ),
                // const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 15,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.kPrimaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: TextStyle(
                            color: AppColors.kPrimaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timestamp != null
                                ? timeago.format(timestamp!.toDate())
                                : 'Unknown time',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Notification Button Widget (for AppBar)
class NotificationButton extends StatelessWidget {
  final String userId;

  const NotificationButton({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Notifications')
          .where('user_id', isEqualTo: int.tryParse(userId))
          .where('is_read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return InkWell(
          onTap: () => showNotificationsDialog(context, userId),
          customBorder: const CircleBorder(),
          child: Badge.count(
            backgroundColor: AppColors.kSecondaryColor,
            textColor: AppColors.kPrimaryColor,
            isLabelVisible: unreadCount > 0,
            largeSize: 10,
            alignment: Alignment.topRight,
            count: unreadCount,
            child: Icon(
              unreadCount > 0 ? Icons.notifications : Icons.notifications_none,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }
}
