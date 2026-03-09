import 'package:flutter/material.dart';

import '../../../../main.dart';
import '../../notifications.dart';

void showNotificationsDialog(BuildContext context, String userId) {
  shouldShowNotificationDialog = false;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Notifications",
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation1, animation2) {
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
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 60,
            ),
            child: NotificationsDialog(userId: userId),
          ),
        ),
      );
    },
  );
}