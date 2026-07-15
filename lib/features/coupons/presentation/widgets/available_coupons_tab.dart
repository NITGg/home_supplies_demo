import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/style/app_colors.dart';
import 'package:tawreedat_courier/l10n/app_localizations.dart';

import '../../data/models/coupns_model.dart';
import '../../manager/coupons_cubit.dart';

import 'coupons_shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Available Coupons Tab
// ─────────────────────────────────────────────────────────────────────────────

class AvailableCouponsTab extends StatelessWidget {
  final List<AvailableCouponModel> coupons;
  final bool isRtl;
  final bool hasActiveCoupon;
  final bool isBuying;

  const AvailableCouponsTab({
    super.key,
    required this.coupons,
    required this.isRtl,
    required this.hasActiveCoupon,
    this.isBuying = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (coupons.isEmpty) {
      return CouponEmptyPlaceholder(
        icon: Icons.local_offer_outlined,
        message: l10n.noCoupons,
      );
    }

    return RefreshIndicator(
      color: AppColors.kPrimaryColor,
      onRefresh: () => context.read<CouponCubit>().loadAll(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: coupons.length,
        itemBuilder: (_, i) {
          return Column(
            children: [
              if (i == 0 && hasActiveCoupon)
                _ActiveCouponBlockBanner(
                    message: l10n.alreadyHasActiveCoupon),
              _AvailableCouponCard(
                coupon: coupons[i],
                isRtl: isRtl,
                hasActiveCoupon: hasActiveCoupon,
                isBuying: isBuying,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner shown above the list when purchase is blocked
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveCouponBlockBanner extends StatelessWidget {
  final String message;
  const _ActiveCouponBlockBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style:
                TextStyle(color: Colors.orange.shade800, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual Available Coupon Card
// ─────────────────────────────────────────────────────────────────────────────

class _AvailableCouponCard extends StatelessWidget {
  final AvailableCouponModel coupon;
  final bool isRtl;
  final bool hasActiveCoupon;
  final bool isBuying;

  const _AvailableCouponCard({
    required this.coupon,
    required this.isRtl,
    required this.hasActiveCoupon,
    this.isBuying = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localTitle = isRtl ? coupon.titleAr : coupon.title;
    final localDesc = isRtl ? coupon.descriptionAr : coupon.description;
    final egp = l10n.egp.trim();

    return Opacity(
      opacity: hasActiveCoupon ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.kPrimaryColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_offer, color: Colors.black),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(localTitle,
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${coupon.durationDays} ${l10n.days}',
                        style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            // ── Body ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localDesc,
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 13)),
                  const SizedBox(height: 12),
                  CouponInfoChip(
                    icon: Icons.star_rounded,
                    label:
                    '+${coupon.bonusCourierFee.toStringAsFixed(0)}% ${l10n.commissionRate}',
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  // ── Action area ──────────────────────────────────
                  if (hasActiveCoupon)
                    CouponLockedRow(
                        label: l10n.completeActiveCouponFirst)
                  else if (isBuying)
                    CouponBuyingProgressRow(label: l10n.couponProcessing)
                  else
                    Row(
                      children: [
                        // Pay with Wallet
                        Expanded(
                          child: CouponBuyButton(
                            label:
                            '${l10n.payWithWallet}  •  ${coupon.price.toStringAsFixed(0)} $egp',
                            icon: Icons.account_balance_wallet_rounded,
                            color: Colors.green.shade600,
                            onTap: () => _confirmBuy(context, coupon,
                                usePoints: false),
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
    );
  }

  void _confirmBuy(
      BuildContext context,
      AvailableCouponModel coupon, {
        required bool usePoints,
      }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => BlocProvider.value(
        value: context.read<CouponCubit>(),
        child: CouponBuyConfirmSheet(
          coupon: coupon,
          usePoints: usePoints,
          isRtl: isRtl,
          onConfirm: () {
            Navigator.pop(context);
            if (usePoints) {
              context.read<CouponCubit>().buyWithPoints(coupon.id);
            } else {
              context.read<CouponCubit>().buyWithWallet(coupon.id);
            }
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buy Confirmation Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class CouponBuyConfirmSheet extends StatelessWidget {
  final AvailableCouponModel coupon;
  final bool usePoints;
  final bool isRtl;
  final VoidCallback onConfirm;

  const CouponBuyConfirmSheet({
    super.key,
    required this.coupon,
    required this.usePoints,
    required this.isRtl,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localTitle = isRtl ? coupon.titleAr : coupon.title;
    final egp = l10n.egp.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Icon(
            usePoints
                ? Icons.stars_rounded
                : Icons.account_balance_wallet_rounded,
            size: 48,
            color: usePoints
                ? AppColors.kSecondaryColor
                : Colors.green.shade600,
          ),
          const SizedBox(height: 12),
          Text('"$localTitle"',
              style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            usePoints
                ? '${l10n.points}  •  ${coupon.durationDays} ${l10n.days}'
                : '${coupon.price.toStringAsFixed(0)} $egp  •  ${coupon.durationDays} ${l10n.days}',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '+${coupon.bonusCourierFee.toStringAsFixed(0)}% ${l10n.commissionRate}',
            style: TextStyle(
                color: Colors.amber.shade700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: usePoints
                        ? AppColors.kSecondaryColor
                        : Colors.green.shade600,
                  ),
                  child: Text(l10n.confirm,
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}