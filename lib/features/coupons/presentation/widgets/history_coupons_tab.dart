import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/style/app_colors.dart';
import 'package:tawreedat_courier/l10n/app_localizations.dart';

import '../../data/models/coupns_model.dart';
import '../../manager/coupons_cubit.dart';

import 'coupons_shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// History Tab
// ─────────────────────────────────────────────────────────────────────────────

class CouponHistoryTab extends StatelessWidget {
  final List<CouponHistoryModel> history;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isRtl;

  const CouponHistoryTab({
    super.key,
    required this.history,
    required this.isLoadingMore,
    required this.hasMore,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (history.isEmpty) {
      return CouponEmptyPlaceholder(
        icon: Icons.history_rounded,
        message: l10n.noTransactionsYet,
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            hasMore &&
            !isLoadingMore) {
          context.read<CouponCubit>().loadMoreHistory();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == history.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: AppColors.kPrimaryColor,
                ),
              ),
            );
          }
          return _CouponHistoryCard(item: history[i], isRtl: isRtl);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual History Card
// ─────────────────────────────────────────────────────────────────────────────

class _CouponHistoryCard extends StatelessWidget {
  final CouponHistoryModel item;
  final bool isRtl;

  const _CouponHistoryCard({required this.item, required this.isRtl});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final expired = item.isExpired;
    final localTitle = isRtl
        ? (item.coupon?.titleAr ?? item.coupon?.title)
        : item.coupon?.title;
    final egp = l10n.egp.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: expired ? Colors.grey.shade100 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_offer_outlined,
              color: expired ? Colors.grey : Colors.green.shade600,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localTitle ?? '${l10n.coupons} #${item.couponId}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.price} ${(item.snapshotPrice/100).toStringAsFixed(2)} $egp  •  '
                  '${l10n.waivedDate.replaceAll(':', '')} ${formatCouponDate(item.endDate)}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: expired ? Colors.grey.shade100 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              expired ? l10n.expired : l10n.active,
              style: TextStyle(
                color: expired ? Colors.grey : Colors.green.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
