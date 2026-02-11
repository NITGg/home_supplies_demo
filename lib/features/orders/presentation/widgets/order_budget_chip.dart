import 'package:flutter/material.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/app_localizations.dart';

class OrderBudgetChip extends StatelessWidget {
  final String budget;

  const OrderBudgetChip({
    super.key,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.kSecondaryColor.withOpacity(0.12),
            AppColors.kSecondaryColor.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.kSecondaryColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 14,
            color: AppColors.kSecondaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            '${l10n?.budget ?? 'Budget'}: $budget ${l10n?.egp ?? 'EGP'}',
            style: AppTextStyles.bold14.copyWith(
              fontSize: 12,
              color: AppColors.kSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}