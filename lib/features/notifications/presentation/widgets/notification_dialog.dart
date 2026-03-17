import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

import '../../../coupons/manager/coupons_cubit.dart';
import '../../../coupons/manager/ocupons_states.dart';
import '../../../coupons/presentation/coupons_ticker_title.dart';
import '../../../home/layout/manager/home_cubit.dart';
import '../../manager/notification_cubit.dart';
import '../../manager/notification_states.dart';
import 'notification_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Notification type constants
// ─────────────────────────────────────────────────────────────────────────────

class _NotifType {
  static const unpaidCommission = 'UNPAID_COMMISSION_THRESHOLD';

  // static const couponExpiring = 'customer_COUPON_EXPIRING';
  static const couponCreated = 'customer_coupon_created';
  static const couponUpdated = 'customer_coupon_updated';
  static const orderCancelled = 'ORDER_CANCELLED';
  static const orderDelivered = 'ORDER_DELIVERED';
  static const badgeUpdated = 'BADGE_UPDATED';
}

// ─────────────────────────────────────────────────────────────────────────────
// Show helper
// ─────────────────────────────────────────────────────────────────────────────

void showNotificationsDialog(
  BuildContext context,
  String userId, {
  HomeCubit? homeCubit,
  CouponCubit? couponCubit, // ← add
}) {
  shouldShowNotificationDialog = false;

  // Capture HomeCubit from the caller's context if not explicitly provided.
  // Must be done HERE (before showGeneralDialog) while the context still has
  // access to HomeLayout's Provider tree.
  final cubit = homeCubit ?? _tryReadHomeCubit(context);

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (dialogContext, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(curved),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 60,
            ),
            child: NotificationsDialog(
              userId: userId,
              homeCubit: cubit, // ← injected directly, no Provider.of needed
              couponCubit: couponCubit,
            ),
          ),
        ),
      );
    },
  );
}

/// Safely reads HomeCubit — returns null instead of throwing if not in tree.
HomeCubit? _tryReadHomeCubit(BuildContext context) {
  try {
    return context.read<HomeCubit>();
  } catch (_) {
    return null;
  }
}

CouponCubit? _tryReadCouponCubit(BuildContext context) {
  try {
    return context.read<CouponCubit>();
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications Dialog
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsDialog extends StatelessWidget {
  final String userId;

  /// Injected from the caller so we never call context.read<HomeCubit>()
  /// inside the dialog route (where HomeCubit is out of scope).
  final HomeCubit? homeCubit;
  final CouponCubit? couponCubit;

  const NotificationsDialog({
    super.key,
    required this.userId,
    this.homeCubit,
    this.couponCubit,
  });

  void _showCouponsDialog(BuildContext context) {
    final state = couponCubit?.state;
    if (state is! CouponsLoaded || state.activeCoupons.isEmpty) {
      debugPrint('⚠️ CouponCubit not available or no active coupons');
      return;
    }
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    showDialog(
      context: context,
      builder: (_) => CouponsDialog(coupons: state.activeCoupons, isAr: isAr),
    );
  }

  // ── Type-based navigation ──────────────────────────────────────────────────

  Future<void> _handleCardNavigation(
    BuildContext context,
    Map<String, dynamic> notifData,
    String notificationId,
  ) async {
    context.read<NotificationsCubit>().markAsRead(notificationId);
    Navigator.of(context).pop();
    if (!context.mounted) return;

    // Payload may be nested under a 'data' key or flat
    final payload = notifData['data'] as Map<String, dynamic>? ?? notifData;
    final type = (payload['type'] as String? ?? '').trim();

    debugPrint('🔔 Card tapped — type: "$type"  payload: $payload');

    switch (type) {
      case _NotifType.unpaidCommission:
        context.push('/WalletScreen');
        return;

      case _NotifType.couponCreated:
      case _NotifType.couponUpdated:
        _showCouponsDialog(context);
        return;

      case _NotifType.orderCancelled:
      case _NotifType.orderDelivered:
        log('ordernoti');
        _requestHistoryTab();
        return;

      case _NotifType.badgeUpdated:
        context.push('/WalletScreen');
        return;

      default:
        debugPrint('⚠️ Unknown notification type: "$type"');
        return;
    }
  }

  // ── HomeCubit helpers (use injected reference — no context.read needed) ───

  void _changeTab(int index) {
    if (homeCubit != null) {
      homeCubit!.changeTab(index);
    } else {
      debugPrint('⚠️ HomeCubit not injected — cannot change tab to $index');
    }
  }

  void _requestHistoryTab() {
    if (homeCubit != null) {
      homeCubit!.requestHistoryTab();
    } else {
      debugPrint('⚠️ HomeCubit not injected — cannot request history tab');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => NotificationsCubit(userId)..loadNotifications(),
        ),
        // BlocProvider(
        //   create: (_) => NotificationSettingsCubit()..loadSettings(),
        // ),
      ],
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
            // ── Header ──────────────────────────────────────────────────
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
                      Text(
                        AppLocalizations.of(context)!.notifications,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      // IconButton(
                      //   onPressed: () => _showSettingsSheet(context),
                      //   icon: const Icon(Icons.tune_rounded),
                      //   color: AppColors.kPrimaryColor,
                      //   tooltip: AppLocalizations.of(
                      //     context,
                      //   )!.notificationSettings,
                      // ),
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
                        tooltip: AppLocalizations.of(context)!.markAllAsRead,
                      ),
                      IconButton(
                        onPressed: hasNotifications
                            ? () async {
                                if (context.mounted) {
                                  await context
                                      .read<NotificationsCubit>()
                                      .clearAllNotifications();
                                  // Navigator.of(context).pop();
                                }
                              }
                            : null,
                        icon: Icon(
                          Icons.delete_sweep,
                          color: hasNotifications
                              ? AppColors.kPrimaryColor
                              : Colors.grey[300],
                        ),
                        tooltip: AppLocalizations.of(context)!.clearAll,
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.grey),
                        tooltip: AppLocalizations.of(context)!.cancel,
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── List ────────────────────────────────────────────────────
            Expanded(
              child: BlocBuilder<NotificationsCubit, NotificationsState>(
                builder: (context, state) {
                  if (state is NotificationsLoading) {
                    return const Center(child: LoadingScreen(isOne: true));
                  }
                  if (state is NotificationsError) {
                    return Center(
                      child: Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                    );
                  }
                  if (state is NotificationsLoaded) {
                    if (state.notifications.isEmpty) {
                      return Center(
                        child: Icon(
                          Icons.notifications_none,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                      );
                    }

                    final isArabic =
                        Localizations.localeOf(context).languageCode == 'ar';

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notification = state.notifications[index];
                        final data =
                            notification.data() as Map<String, dynamic>?;
                        if (data == null) return const SizedBox.shrink();

                        return NotificationCard(
                          notificationId: notification.id,
                          isRead: data['is_read'] ?? false,
                          title: isArabic
                              ? data['title_ar'] ?? data['title'] ?? 'No Title'
                              : data['title'] ?? 'No Title',
                          description: isArabic
                              ? data['desc_ar'] ?? data['desc'] ?? ''
                              : data['desc'] ?? '',
                          timestamp: data['created_at'] as Timestamp?,
                          onTap: () => _handleCardNavigation(
                            context,
                            data,
                            notification.id,
                          ),
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

  // void _showSettingsSheet(BuildContext context) {
  //   final settingsCubit = context.read<NotificationSettingsCubit>();
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: Colors.white,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //     ),
  //     builder: (_) => BlocProvider.value(
  //       value: settingsCubit,
  //       child: const NotificationSettingsSheet(),
  //     ),
  //   );
  // }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Button (nav bar / app bar)
// ─────────────────────────────────────────────────────────────────────────────

class NotificationButton extends StatelessWidget {
  final String userId;

  const NotificationButton({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return Icon(Icons.notifications_none, color: Colors.grey);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Notifications')
          .where('user_id', isEqualTo: int.tryParse(userId))
          .where('is_read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return InkWell(
          // NotificationButton lives inside HomeLayout so HomeCubit IS
          // available here — capture it before the dialog route is pushed.
          onTap: () => showNotificationsDialog(
            context,
            userId,
            homeCubit: _tryReadHomeCubit(context),
            couponCubit: _tryReadCouponCubit(context),
          ),
          customBorder: const CircleBorder(),
          child: Badge.count(
            backgroundColor: AppColors.kSecondaryColor,
            textColor: AppColors.kPrimaryColor,
            isLabelVisible: unreadCount > 0,
            largeSize: 10,
            alignment: Alignment.topRight,
            count: unreadCount,
            child: Icon(
              unreadCount > 0
                  ? Icons.notifications
                  : Icons.notifications_none,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }
}
