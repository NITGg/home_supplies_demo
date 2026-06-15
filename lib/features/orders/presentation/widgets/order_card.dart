import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/widgets/banners.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/formatDate.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../refunds/manager/refund_cubit.dart';
import '../../../refunds/presentation/refund_request_sheet.dart';
import 'sheets/supplier_review_bottom_sheet.dart';
import '../../data/models/order_model.dart';
import '../../manager/order_cubit.dart';
import '../../manager/order_states.dart';
import 'order_budget_chip.dart';
import 'order_route_section.dart';
import '../../../chat/config/chat_injection.dart';

Future<void> openPhoneApp(String phoneNumber) async {
  final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
  if (await canLaunchUrl(phoneUri)) {
    await launchUrl(phoneUri, mode: LaunchMode.platformDefault);
  } else {
    debugPrint('Cannot open phone app for $phoneNumber');
  }
}

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onViewProposals;
  final VoidCallback onCancel;
  final VoidCallback? onRetrySuccess;
  final bool hasNewOffer;
  final int? roleId;
  final int currentUserId;

  const OrderCard({
    super.key,
    required this.order,
    required this.onViewProposals,
    required this.onCancel,
    required this.currentUserId,
    this.onRetrySuccess,
    this.hasNewOffer = false,
    this.roleId,
  });

  // ── Status helpers ─────────────────────────────────────────────────────────

  Color _statusColor() {
    switch (order.displayStatus) {
      case 'PENDING':
        return Colors.orange;
      case 'PENDING_PAYMENT':
        return Colors.deepOrange;
      case 'SCHEDULED':
        return const Color(0xFF5C6BC0);
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon() {
    switch (order.displayStatus) {
      case 'PENDING':
        return Icons.schedule;
      case 'PENDING_PAYMENT':
        return Icons.credit_card_outlined;
      case 'SCHEDULED':
        return Icons.event_available_rounded;
      case 'IN_PROGRESS':
        return Icons.local_shipping;
      case 'DELIVERED':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.remove_circle;
      default:
        return Icons.info;
    }
  }

  String _statusLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (order.displayStatus) {
      case 'PENDING':
        return l10n?.pending ?? 'Pending';
      case 'PENDING_PAYMENT':
        return l10n?.pendingPayment ?? 'في انتظار الدفع';
      case 'SCHEDULED':
        return l10n?.scheduled ?? 'Scheduled';
      case 'IN_PROGRESS':
        return l10n?.inProgress ?? 'In Progress';
      case 'DELIVERED':
        return l10n?.delivered ?? 'Delivered';
      case 'CANCELLED':
        return l10n?.cancelled ?? 'Cancelled';
      case 'EXPIRED':
        return l10n?.expired ?? 'Expired';
      case 'SEARCHING_FAILED':
        return l10n?.searchingFailed ?? 'Searching Failed';
      default:
        return order.displayStatus ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _statusColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: AppColors.kSecondaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, statusColor.withOpacity(0.03)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(statusColor, context),
            // ── Scheduled banner (real SCHEDULED status with date) ──────────
            if (order.isOrderScheduled &&
                order.orderScheduleAt != null &&
                order.status == 'SCHEDULED')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _buildScheduledBanner(context),
              ),
            // ── Not ready for pickup banner (no date) ───────────────────────
            if (order.isTakeTime && !order.isReadyForPickUp)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _buildNotReadyBanner(context),
              ),
            _buildProductInfo(),
            _OrderItemsSection(order: order),
            _buildResultInfo(context),
            if (order.status == "IN_PROGRESS") _buildCourierFooter(context),
            if (order.hasPendingPriceAdjustment)
              _PriceAdjustmentFooter(order: order),
            if (order.isPending || order.isScheduled) _buildActionButtons(l10n),
            if (order.status == 'EXPIRED') _buildRetryFooter(context, order.id),
            if (order.status == "IN_PROGRESS" && roleId == 4)
              _buildConfirmDeliveryFooter(context),
            if (order.status == "IN_PROGRESS" && order.confirmationOtp != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  spacing: 10,
                  children: [
                    const Icon(Icons.qr_code_rounded),
                    Text(
                      style: AppTextStyles.bold14.copyWith(fontSize: 12),
                      "${l10n.confirmDeliveryCode}: ${order.confirmationOtp}",
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: order.confirmationOtp ?? ''),
                        );
                        if (!context.mounted) return;
                        showInfoBanner(context, l10n.copiedToClipboard);
                      },
                      icon: const Icon(Icons.copy, color: Color(0xFF1E87E3)),
                    ),
                  ],
                ),
              ),
            if (order.isDelivered &&
                order.orderItems.isNotEmpty &&
                order.isRefundable &&
                (order.orderItems.any((i) => i.product.isRefundable)))
              _buildRefundButton(context),
            if (order.isDelivered && order.type == 'CATALOG_PURCHASE')
              _buildRateSupplierButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _openRefundSheet(context),
          icon: const Icon(Icons.assignment_return_outlined, size: 18),
          label: Text(
            l10n.requestRefund,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildRateSupplierButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _openSupplierReviewSheet(context),
          icon: const Icon(Icons.star_outline_rounded, size: 18),
          label: Text(
            l10n.rateTheSupplier,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _openSupplierReviewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupplierReviewBottomSheet(orderId: order.id!),
    );
  }

  void _openRefundSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => RefundCubit()..loadReasons(),
        child: RefundRequestSheet(order: order),
      ),
    );
  }

  // ── Scheduled banner (with date/time) ─────────────────────────────────────

  Widget _buildScheduledBanner(BuildContext context) {
    final dt = order.orderScheduleAt!;
    final dateStr = '${dt.day}/${dt.month}/${dt.year}';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    final timeStr = '$hour:$minute $period';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_rounded,
            size: 16,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$dateStr - $timeStr',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Not ready for pickup banner (no date/time) ────────────────────────────

  Widget _buildNotReadyBanner(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_rounded,
            size: 16,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.scheduled,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(Color statusColor, BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.07),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_statusIcon(), color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderNumber ?? 'N/A',
                  style: AppTextStyles.bold14.copyWith(fontSize: 12),
                ),
                Text(
                  formatDate(context, order.createdAt ?? DateTime.now()),
                  style: AppTextStyles.regular14.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon(), size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  (order.collectedAt != null && order.status == 'IN_PROGRESS')
                      ? AppLocalizations.of(context)!.outForDelivery
                      : _statusLabel(context),
                  style: AppTextStyles.bold14.copyWith(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Product info ───────────────────────────────────────────────────────────

  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (order.productDescription != null &&
                            order.orderItems.isNotEmpty)
                          Expanded(
                            child: Text(
                              order.productDescription!,
                              style: AppTextStyles.bold14.copyWith(
                                fontSize: 15,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (order.status == 'IN_PROGRESS' &&
                            order.collectedAt == null)
                          IconButton(
                            onPressed: onCancel,
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (order.budget != '0') ...[
                          Builder(
                            builder: (_) {
                              String budgetText = order.payableAmount ?? '';
                              return order.status != 'PENDING'
                                  ? OrderBudgetChip(budget: budgetText)
                                  : const SizedBox.shrink();
                            },
                          ),
                        ],
                        if (order.paymentMethod == 'CASH' ||
                            order.paymentMethod == 'WALLET') ...[
                          const SizedBox(width: 8),
                          _PaymentMethodChip(
                            paymentMethod: order.paymentMethod!,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OrderRouteSection(order: order),
        ],
      ),
    );
  }

  // ── Result info ───────────────────────────────────────────────────────────

  Widget _buildResultInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Column(
        children: [
          if (order.isCancelled && order.cancelledReason != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.reason,
                          style: AppTextStyles.bold14.copyWith(
                            fontSize: 12,
                            color: Colors.red.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.cancelledReason!,
                          style: AppTextStyles.regular14.copyWith(
                            fontSize: 12,
                            color: Colors.red.shade800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (order.isDelivered && order.deliveredAt != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${AppLocalizations.of(context)!.delivered}: ${formatDate(context, order.deliveredAt!)}',
                    style: AppTextStyles.medium18.copyWith(
                      fontSize: 13,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Courier footer ─────────────────────────────────────────────────────────

  Widget _buildCourierFooter(BuildContext context) {
    final hasPhone =
        order.courierPhone != null && order.courierPhone!.isNotEmpty;
    final hasPhoto =
        order.courierPhoto != null && order.courierPhoto!.isNotEmpty;
    final canChat = order.courierId != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: hasPhoto
                ? NetworkImage(order.courierPhoto!)
                : null,
            onBackgroundImageError: hasPhoto ? (_, __) {} : null,
            child: hasPhoto
                ? null
                : Text(
                    _initials(order.courierName ?? ''),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.courierName ?? '',
                  style: AppTextStyles.bold14.copyWith(
                    fontSize: 13,
                    color: Colors.blue.shade900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasPhone)
                  Text(
                    textDirection: ui.TextDirection.ltr,
                    order.courierPhone!,
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canChat) ...[
                Material(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      ChatNavigator.openChatWithUser(
                        context,
                        targetUserId: order.courierUserId ?? 0,
                        orderId: order.id,
                        chatTitle: order.courierName,
                        chatAvatarUrl: order.courierPhoto,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.chat_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (hasPhone)
                Material(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => openPhoneApp(order.courierPhone!),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.phone, color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmDeliveryFooter(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<OrderCubit, OrderState>(
      listenWhen: (_, current) =>
          current is DeliveryConfirmed || current is OrderError,
      listener: (context, state) {
        if (state is DeliveryConfirmed) {
          showSuccessBanner(context, l10n.deliveryConfirmed);
        } else if (state is OrderError) {
          showErrorBanner(context, state.message);
        }
      },
      buildWhen: (_, current) =>
          current is DeliveryConfirming ||
          current is DeliveryConfirmed ||
          current is OrderError ||
          current is OrdersLoaded,
      builder: (context, state) {
        final isLoading = state is DeliveryConfirming;

        return Column(
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: CircularProgressIndicator(
                          color: AppColors.kSecondaryColor,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showConfirmDialog(context, l10n),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          l10n.confirmDelivery,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.confirmDelivery),
        content: Text('${l10n.confirmDeliveryMessage} \n ${order.orderNumber}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<OrderCubit>().confirmDelivery(
                orderId: order.id!,
                courierId: order.courierId!,
                courierUserId: order.courierUserId!,
              );
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons(AppLocalizations l10n) {
    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              if (order.type != 'CATALOG_PURCHASE' &&
                  !order.isOrderScheduled) ...[
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onViewProposals,
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: Text(
                            l10n.viewProposals,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (hasNewOffer)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: _PulsingNewOfferDot(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(
                    l10n.cancel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRetryFooter(BuildContext context, int? orderId) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<OrderCubit, OrderState>(
      listenWhen: (_, current) =>
          current is OrderRetried || current is OrderRetryError,
      listener: (context, state) {
        if (state is OrderRetried) {
          onRetrySuccess?.call();
        } else if (state is OrderRetryError) {
          showErrorBanner(context, state.message);
        }
      },
      buildWhen: (_, current) =>
          current is RetryingOrder ||
          current is OrderRetried ||
          current is OrderRetryError ||
          current is OrdersLoaded,
      builder: (context, state) {
        final isLoading = state is RetryingOrder;

        return Column(
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: CircularProgressIndicator(
                          color: AppColors.kSecondaryColor,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            context.read<OrderCubit>().retryOrder(orderId),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(
                          l10n.retry,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PulsingNewOfferDot extends StatefulWidget {
  @override
  State<_PulsingNewOfferDot> createState() => _PulsingNewOfferDotState();
}

class _PulsingNewOfferDotState extends State<_PulsingNewOfferDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.75,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.5),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Price Adjustment Footer
// ─────────────────────────────────────────────────────────────────────────────

class _PriceAdjustmentFooter extends StatelessWidget {
  final Order order;

  const _PriceAdjustmentFooter({required this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<OrderCubit, OrderState>(
      listenWhen: (_, current) =>
          current is PriceAdjustmentResponded || current is OrderError,
      listener: (context, state) {},
      buildWhen: (_, current) =>
          current is PriceAdjustmentResponding ||
          current is PriceAdjustmentResponded ||
          current is OrderError ||
          current is OrdersLoaded,
      builder: (context, state) {
        final isLoading = state is PriceAdjustmentResponding;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFECB3),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.price_change_outlined,
                      size: 18,
                      color: Color(0xFFF57F17),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.budgetNotEnough,
                        style: AppTextStyles.bold14.copyWith(
                          fontSize: 13,
                          color: const Color(0xFFE65100),
                        ),
                      ),
                    ),
                    _PulsingDot(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.budget,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.budget} ${l10n.egp}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                              decoration: TextDecoration.lineThrough,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            l10n.newBudget,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.actualPrice} ${l10n.egp}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFFE65100),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFFFE082)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: CircularProgressIndicator(
                            color: AppColors.kPrimaryColor,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _respond(context, 'REJECTED'),
                              icon: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red.shade600,
                              ),
                              label: Text(
                                l10n.reject,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                side: BorderSide(
                                  color: Colors.red.shade300,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _respond(context, 'ACCEPTED'),
                              icon: const Icon(Icons.check, size: 16),
                              label: Text(
                                l10n.accept,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.kPrimaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _respond(BuildContext context, String status) {
    context.read<OrderCubit>().respondToPriceAdjustment(
      orderId: order.id!,
      status: status,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment Method Chip
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodChip extends StatelessWidget {
  final String paymentMethod;

  const _PaymentMethodChip({required this.paymentMethod});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final isCash = paymentMethod == 'CASH';
    final IconData icon = isCash
        ? Icons.payments_outlined
        : Icons.account_balance_wallet_outlined;
    final String label = isCash ? l10n.cod : l10n.wallet;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.kSecondaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.kSecondaryColor.withOpacity(0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.kSecondaryColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.bold14.copyWith(
              fontSize: 10,
              color: AppColors.kSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated pulsing dot
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFFE65100),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _OrderItemsSection extends StatefulWidget {
  final Order order;

  const _OrderItemsSection({required this.order});

  @override
  State<_OrderItemsSection> createState() => _OrderItemsSectionState();
}

class _OrderItemsSectionState extends State<_OrderItemsSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;
  late final Animation<double> _rotateAnim;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _rotateAnim = Tween<double>(begin: 0, end: 0.5).animate(_expandAnim);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  bool get _isCatalog => widget.order.orderItems.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final order = widget.order;

    if (!_isCatalog &&
        (order.productDescription == null ||
            order.productDescription!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final itemCount = _isCatalog ? order.orderItems.length : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      _isCatalog
                          ? Icons.receipt_long_outlined
                          : Icons.notes_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isCatalog
                            ? '${l10n.products} ($itemCount)'
                            : l10n.description,
                        style: AppTextStyles.bold14.copyWith(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: _rotateAnim,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Column(
                children: [
                  Divider(height: 1, color: Colors.grey.shade200),
                  if (_isCatalog)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: order.orderItems.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final item = order.orderItems[index];
                        final name = item.product.nameAr.isNotEmpty
                            ? item.product.nameAr
                            : item.product.name;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.kPrimaryColor.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.kPrimaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: AppTextStyles.regular14.copyWith(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.kPrimaryColor.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '× ${item.quantity}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.kPrimaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        order.productDescription!,
                        style: AppTextStyles.regular14.copyWith(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
