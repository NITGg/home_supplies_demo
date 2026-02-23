
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';

class WalletBalanceCard extends StatelessWidget {
  final double balance;
  final bool isActive;
  final String? freezeReason;
  final double totalUnpaid;
  final double totalPenalties;
  final double availableBalance;

  const WalletBalanceCard({
    super.key,
    required this.balance,
    required this.isActive,
    this.freezeReason,
    required this.totalUnpaid,
    required this.totalPenalties,
    required this.availableBalance,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencyFormatter = NumberFormat.currency(
      symbol: l10n.egp,
      decimalDigits: 2,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D3436), Color(0xFF636E72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.walletBalance,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(balance),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withOpacity(0.2)
                  : Colors.red.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.warning,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? l10n.active : l10n.frozen,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (!isActive && freezeReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                freezeReason!,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ],

          // Financial Summary
          if (totalUnpaid > 0 || totalPenalties > 0) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            FinancialRow(
              label: l10n.pendingPenalties,
              value: currencyFormatter.format(totalPenalties),
              isNegative: true,
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            FinancialRow(
              label: l10n.availableBalance,
              value: currencyFormatter.format(availableBalance),
              isNegative: availableBalance < 0,
              isBold: true,
            ),
          ],
        ],
      ),
    );
  }
}

class FinancialRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isNegative;
  final bool isBold;

  const FinancialRow({
    super.key,
    required this.label,
    required this.value,
    this.isNegative = false,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            color: Colors.white.withOpacity(0.9),
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          isNegative ? '- $value' : value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            color: Colors.white,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
