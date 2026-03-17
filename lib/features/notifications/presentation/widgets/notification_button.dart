import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/style/app_colors.dart';
import '../../notifications.dart';
import 'notification_dialog.dart';

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