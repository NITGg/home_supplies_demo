import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/style/app_colors.dart';
import '../../manager/notification_cubit.dart';

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
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.done, color: Colors.white, size: 28),
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.clear_all_rounded, color: Colors.white, size: 28),
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
              color: isRead ? Colors.grey[200]! : Colors.orange.withOpacity(0.3),
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
                          Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            timestamp != null
                                ? timeago.format(timestamp!.toDate())
                                : 'Unknown time',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
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