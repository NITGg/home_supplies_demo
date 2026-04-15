import 'package:flutter/material.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';

class InsufficientBalanceSheet extends StatelessWidget {
  final double currentBalance;
  final double requiredAmount;
  final double shortfall;
  final bool isShopping;
  final AppLocalizations l10n;
  final VoidCallback onTopUp;

  const InsufficientBalanceSheet({
    super.key,
    required this.currentBalance,
    required this.requiredAmount,
    required this.shortfall,
    required this.isShopping,
    required this.l10n,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 32,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.insufficientBalance,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isShopping
                ? l10n.insufficientBalanceShoppingDesc
                : l10n.insufficientBalanceShippingDesc,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                BalanceRow(
                  label: l10n.currentBalance,
                  amount: currentBalance,
                  egpLabel: l10n.egp,
                  color: Colors.green.shade700,
                  icon: Icons.account_balance_wallet,
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                BalanceRow(
                  label: l10n.requiredAmount,
                  amount: requiredAmount,
                  egpLabel: l10n.egp,
                  color: Colors.blue.shade700,
                  icon: Icons.receipt_long_outlined,
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                BalanceRow(
                  label: l10n.shortfall,
                  amount: shortfall,
                  egpLabel: l10n.egp,
                  color: Colors.red.shade700,
                  icon: Icons.arrow_downward_rounded,
                  highlight: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTopUp,
              icon: const Icon(Icons.add_card_rounded),
              label: Text(
                l10n.topUpNow,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.notNow,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class BalanceRow extends StatelessWidget {
  final String label;
  final double amount;
  final String egpLabel;
  final Color color;
  final IconData icon;
  final bool highlight;

  const BalanceRow({
    super.key,
    required this.label,
    required this.amount,
    required this.egpLabel,
    required this.color,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: highlight
          ? BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      )
          : null,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} $egpLabel',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}