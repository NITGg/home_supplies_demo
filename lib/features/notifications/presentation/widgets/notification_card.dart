import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/style/app_colors.dart';
import '../../../orders/presentation/widgets/order_card.dart';
import '../../manager/notifications_cubit.dart';


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

  Widget _markReadBackground() => Container(
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.only(left: 20),
    decoration: BoxDecoration(
      color: AppColors.kPrimaryColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.done, color: Colors.white, size: 28),
  );

  Widget _deleteBackground() => Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    decoration: BoxDecoration(
      color: Colors.red,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.clear_all_rounded, color: Colors.white, size: 28),
  );

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // In RTL Flutter mirrors swipe directions, so we flip intent accordingly:
    // LTR: startToEnd = mark read, endToStart = delete
    // RTL: startToEnd = delete,    endToStart = mark read
    final markReadDirection =
    isRtl ? DismissDirection.endToStart : DismissDirection.startToEnd;
    final deleteDirection =
    isRtl ? DismissDirection.startToEnd : DismissDirection.endToStart;

    return Dismissible(
      key: Key(notificationId),
      confirmDismiss: (direction) async {
        if (direction == deleteDirection) {
          await context
              .read<NotificationsCubit>()
              .deleteNotification(notificationId);
          return true;
        } else if (direction == markReadDirection) {
          if (!isRead) {
            await context
                .read<NotificationsCubit>()
                .markAsRead(notificationId);
          }
          return false;
        }
        return false;
      },
      // background  = behind startToEnd swipe
      // in RTL startToEnd is delete, in LTR it is mark-read
      background:
      isRtl ? _deleteBackground() : _markReadBackground(),
      // secondaryBackground = behind endToStart swipe
      // in RTL endToStart is mark-read, in LTR it is delete
      secondaryBackground:
      isRtl ? _markReadBackground() : _deleteBackground(),
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
                                ? formatDate(context, timestamp!.toDate())
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