import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/core/style/text_styles.dart';
import 'package:tawreedat_courier/l10n/app_localizations.dart';

import '../../manager/coupons_cubit.dart';
import '../../manager/coupons_states.dart';

/// Drop this anywhere inside the CouponCubit provider tree.
/// Auto-hides when there is no active coupon.
/// Black text & icons on primary-color background.
class ActiveCouponBanner extends StatelessWidget {
  const ActiveCouponBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return BlocBuilder<CouponCubit, CouponState>(
      builder: (context, state) {
        if (state is! CouponDataLoaded || state.activeCoupon == null) {
          return const SizedBox.shrink();
        }

        final active = state.activeCoupon!;
        // Use localized coupon title from model fields
        final couponTitle = isRtl
            ? (active.coupon?.titleAr ?? active.coupon?.title ?? l10n.coupons)
            : (active.coupon?.title ?? l10n.coupons);
        final daysLeft = active.daysRemaining;

        return GestureDetector(
          onTap: () => context.push('/wallet/coupons'),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // Primary color bg → black text & icons
              gradient: const LinearGradient(
                colors: [Color(0xFF2D3436), Color(0xFF636E72)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        couponTitle,
                        style: AppTextStyles.bold14.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        // bonus_courier_fee = extra commission % on deliveries
                        // l10n.commissionRate → "Commission Rate" / "نسبة عمولة"
                        '+${active.snapshotBonusCourierFee.toStringAsFixed(0)}% ${l10n.commissionRate}  •  $daysLeft ${l10n.days}',
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }
}
