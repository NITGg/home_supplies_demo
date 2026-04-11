import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../addresses/data/models/governorate_model.dart';
import '../../addresses/manager/governorate_cubit.dart';
import '../../addresses/manager/governorate_states.dart';
import '../../orders/presentation/widgets/sheets/create_order_sheet/create_order_sheet.dart';
import '../../wallet/manager/wallet_cubit.dart';
import '../data/models/coupons_model.dart';

class FirstOrderDiscountDialog extends StatelessWidget {
  final Coupon coupon;
  final GovernoratesResponse governorates; // ← NEW
  final double walletBalance;

  const FirstOrderDiscountDialog({super.key, required this.coupon,required this.governorates,
    required this.walletBalance,});

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context)?.localeName == 'ar';

    final buttonLabel = isAr
        ? (coupon.buttonTextAr?.isNotEmpty == true
        ? coupon.buttonTextAr!
        : coupon.buttonText ?? (isAr ? 'استخدم الكود' : 'Use Code'))
        : (coupon.buttonText?.isNotEmpty == true
        ? coupon.buttonText!
        : 'Use Code');

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Close button ──────────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.close, size: 18, color: Colors.black54),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Image ─────────────────────────────────────────────────
            if (coupon.image != null && coupon.image!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  coupon.image!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.scaleDown,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 20),

            // // ── Coupon code chip ──────────────────────────────────────
            // Container(
            //   padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            //   decoration: BoxDecoration(
            //     color: Colors.orange.shade50,
            //     borderRadius: BorderRadius.circular(10),
            //     border: Border.all(color: Colors.orange.shade200),
            //   ),
            //   child: Text(
            //     coupon.code,
            //     style: const TextStyle(
            //       fontSize: 20,
            //       fontWeight: FontWeight.bold,
            //       letterSpacing: 2,
            //       color: Colors.black87,
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 24),

            // ── Action button ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kPrimaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog first
                  _openCreateOrderSheet(context);
                },
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateOrderSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateOrderBottomSheet(
        governorates: governorates,    // ← from field, not context.read
        walletBalance: walletBalance,  // ← from field, not context.read
        initialCouponCode: coupon.code,
      ),
    );
  }
}