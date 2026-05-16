import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/utils/formatDate.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

import '../../../chat/config/chat_injection.dart';
import '../../../chat/manager/chat_cubit.dart';
import '../../../chat/presentation/chat_screen.dart';
import '../../../coupons/manager/coupons_cubit.dart';
import '../../../coupons/manager/coupons_states.dart';
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
  static const couponCreated = 'customer_coupon_created';
  static const newMessage = 'NEW_MESSAGE';
  static const couponUpdated = 'customer_coupon_updated';
  static const orderCancelled = 'ORDER_CANCELLED';
  static const orderExpired = 'ORDER_EXPIRED';
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
  CouponCubit? couponCubit,
}) {
  shouldShowNotificationDialog = false;

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
              homeCubit: cubit,
              couponCubit: couponCubit,
            ),
          ),
        ),
      );
    },
  );
}

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
      builder: (_) => BlocProvider.value(
        value: couponCubit!,
        child: CouponsDialog(isAr: isAr),
      ),
    );
  }

  Future<void> _handleCardNavigation(
    BuildContext context,
    Map<String, dynamic> notifData,
    String notificationId,
  ) async {
    context.read<NotificationsCubit>().markAsRead(notificationId);
    final payload = notifData['data'] as Map<String, dynamic>? ?? notifData;
    final type = (payload['type'] as String? ?? '').trim();
    Navigator.of(context).pop();
    if (!context.mounted) return;
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
      case _NotifType.orderExpired:
        dLog('ordernoti');
        _requestHistoryTab();
        return;

      case _NotifType.newMessage:
        dLog('messagenoti');
        _openChat(context, payload, notifData);
        return;

      case _NotifType.badgeUpdated:
        context.push('/WalletScreen');
        return;

      default:
        debugPrint('⚠️ Unknown notification type: "$type"');
        return;
    }
  }

  void _openChat(
    BuildContext context,
    Map<String, dynamic> payload,
    Map<String, dynamic> notifData,
  ) {
    final chatId = payload['chatId'];
    if (chatId == null) return;
    final id = chatId is int ? chatId : int.tryParse(chatId.toString());
    if (id == null) return;

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final chatTitle = isAr
        ? (notifData['title_ar'] ?? notifData['title']) as String?
        : notifData['title'] as String?;
    final chatAvatarUrl = notifData['sender_photo'] as String?;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => ChatCubit(
            repo: ChatModule.repository,
            currentUserId: ChatModule.currentUserId,
          )..joinExistingChat(id),
          child: ChatScreen(
            currentUserId: ChatModule.currentUserId,
            chatTitle: chatTitle,
            chatAvatarUrl: chatAvatarUrl,
          ),
        ),
      ),
    );
  }

  void _requestHistoryTab() {
    if (homeCubit != null) {
      homeCubit!.requestHistoryTab();
    } else {
      debugPrint('⚠️ HomeCubit not injected — cannot request history tab');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => NotificationsCubit(userId)..loadNotifications(),
        ),
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
            // ── Header ────────────────────────────────────────────────────
            _DialogHeader(),

            // ── Body ──────────────────────────────────────────────────────
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

                    // ── Split into messages vs everything else ─────────────
                    final allDocs = state.notifications;

                    final messageDocs = allDocs
                        .whereType<DocumentSnapshot>()
                        .where((doc) {
                          final data = doc.data() as Map<String, dynamic>?;
                          final payload =
                              data?['data'] as Map<String, dynamic>? ??
                              data ??
                              {};
                          final type = (payload['type'] as String? ?? '')
                              .trim();
                          return type == _NotifType.newMessage;
                        })
                        .toList();

                    final otherDocs = allDocs
                        .whereType<DocumentSnapshot>()
                        .where((doc) {
                          final data = doc.data() as Map<String, dynamic>?;
                          final payload =
                              data?['data'] as Map<String, dynamic>? ??
                              data ??
                              {};
                          final type = (payload['type'] as String? ?? '')
                              .trim();
                          return type != _NotifType.newMessage;
                        })
                        .toList();

                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      children: [
                        // ── Messages section ───────────────────────────────
                        if (messageDocs.isNotEmpty) ...[
                          _MessageNotificationSection(
                            docs: messageDocs,
                            isArabic: isArabic,
                            onTap: (data, id) =>
                                _handleCardNavigation(context, data, id),
                          ),
                          if (otherDocs.isNotEmpty) const SizedBox(height: 16),
                        ],

                        // ── Regular notifications ──────────────────────────
                        if (otherDocs.isNotEmpty) ...[
                          if (messageDocs.isNotEmpty)
                            _SectionLabel(
                              label: AppLocalizations.of(
                                context,
                              )!.notifications,
                              icon: Icons.notifications_outlined,
                            ),
                          const SizedBox(height: 8),
                          ...otherDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>?;
                            if (data == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: NotificationCard(
                                notificationId: doc.id,
                                isRead: data['is_read'] ?? false,
                                title: isArabic
                                    ? data['title_ar'] ??
                                          data['title'] ??
                                          'No Title'
                                    : data['title'] ?? 'No Title',
                                description: isArabic
                                    ? data['desc_ar'] ?? data['desc'] ?? ''
                                    : data['desc'] ?? '',
                                timestamp: data['created_at'] as Timestamp?,
                                onTap: () => _handleCardNavigation(
                                  context,
                                  data,
                                  doc.id,
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Messages section — grouped chat notifications as compact conversation rows
// ─────────────────────────────────────────────────────────────────────────────

class _MessageNotificationSection extends StatefulWidget {
  final List<DocumentSnapshot> docs;
  final bool isArabic;
  final void Function(Map<String, dynamic> data, String id) onTap;

  const _MessageNotificationSection({
    required this.docs,
    required this.isArabic,
    required this.onTap,
  });

  @override
  State<_MessageNotificationSection> createState() =>
      _MessageNotificationSectionState();
}

class _MessageNotificationSectionState
    extends State<_MessageNotificationSection> {
  // Show only the first 3 by default; user can expand.
  static const _initialLimit = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final docs = widget.docs;
    final visibleDocs = _expanded ? docs : docs.take(_initialLimit).toList();
    final hiddenCount = docs.length - _initialLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ───────────────────────────────────────────────
        Row(
          children: [
            _SectionLabel(
              label: AppLocalizations.of(context)!.messages,
              icon: Icons.chat_bubble_outline_rounded,
            ),
            const Spacer(),
            // Unread badge
            BlocBuilder<NotificationsCubit, NotificationsState>(
              builder: (context, state) {
                final unread = docs.whereType<DocumentSnapshot>().where((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  return data?['is_read'] == false;
                }).length;
                if (unread == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.kPrimaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Conversation rows ────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              ...visibleDocs.asMap().entries.map((entry) {
                final index = entry.key;
                final doc = entry.value;
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) return const SizedBox.shrink();

                final isRead = data['is_read'] as bool? ?? false;
                final payload = data['data'] as Map<String, dynamic>? ?? data;
                final senderName = widget.isArabic
                    ? (data['title_ar'] ?? data['title'] ?? 'Unknown') as String
                    : (data['title'] ?? 'Unknown') as String;
                final preview = widget.isArabic
                    ? (data['desc_ar'] ?? data['desc'] ?? '') as String
                    : (data['desc'] ?? '') as String;
                final avatarUrl = data['sender_photo'] as String?;
                final timestamp = data['created_at'] as Timestamp?;

                return Column(
                  children: [
                    if (index != 0) Divider(height: 1, color: Colors.grey[200]),
                    _ConversationRow(
                      senderName: senderName,
                      preview: preview,
                      avatarUrl: avatarUrl,
                      timestamp: timestamp,
                      isRead: isRead,
                      onTap: () => widget.onTap(data, doc.id),
                    ),
                  ],
                );
              }),

              // ── Expand / collapse toggle ─────────────────────────────
              if (docs.length > _initialLimit) ...[
                Divider(height: 1, color: Colors.grey[200]),
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _expanded
                              ? AppLocalizations.of(context)!.showLess
                              : AppLocalizations.of(
                                  context,
                                )!.showMoreCount(hiddenCount),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.kPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.kPrimaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single conversation row inside the messages card
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationRow extends StatelessWidget {
  final String senderName;
  final String preview;
  final String? avatarUrl;
  final Timestamp? timestamp;
  final bool isRead;
  final VoidCallback onTap;

  const _ConversationRow({
    required this.senderName,
    required this.preview,
    required this.avatarUrl,
    required this.timestamp,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.kPrimaryColor.withOpacity(0.12),
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: avatarUrl == null
                      ? Text(
                          senderName.isNotEmpty
                              ? senderName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: AppColors.kPrimaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                if (!isRead)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.kPrimaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Name + preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      style: TextStyle(
                        fontSize: 13,
                        color: isRead ? Colors.grey[500] : Colors.black54,
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Timestamp + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (timestamp != null)
                  Text(
                    formatDate(context,timestamp!.toDate()),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.grey[600]),
        const SizedBox(width: 5),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey[600],
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog header
// ─────────────────────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
              state is NotificationsLoaded && state.notifications.isNotEmpty;

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
                  color: hasUnread ? AppColors.kPrimaryColor : Colors.grey[300],
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
    );
  }
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
      return const Icon(Icons.notifications_none, color: Colors.grey);
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
              unreadCount > 0 ? Icons.notifications : Icons.notifications_none,
              color: Colors.grey.shade700,
            ),
          ),
        );
      },
    );
  }
}
