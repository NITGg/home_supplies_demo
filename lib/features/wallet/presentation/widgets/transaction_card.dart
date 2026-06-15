import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../data/models/transaction_penality_models.dart';

class TransactionCard extends StatelessWidget {
  final WalletTransactionModel transaction;

  const TransactionCard({super.key, required this.transaction});

  Color _getTypeColor() {
    switch (transaction.type) {
      case 'TOPUP':
        return Colors.green.shade600;
      case 'MANUAL_INCREASE':
        return Colors.green.shade600;
      case 'WITHDRAWAL':
        return const Color(0xFF6C5CE7);
      case 'ESCROW_RELEASE' || 'ESCROW_REMOVE':
        return Colors.green.shade600;
      case 'PENALTY':
        return const Color(0xFFE17055);
      case 'COMMISSION_DEDUCTION':
        return const Color(0xFFFF6B6B);
      case 'MANUAL_DECREASE':
        return const Color(0xFFFF6B6B);
      case 'COUPON_PURCHASE':
        return Colors.green.shade600;
      case 'PLATFORM_COD_COMMISSION':
        return const Color(0xFFFF6B6B);
      case 'ORDER_PAYMENT':
        return const Color(0xFF185FA5);
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon() {
    switch (transaction.type) {
      case 'TOPUP' || 'MANUAL_INCREASE':
        return Icons.add_circle_outline;
      case 'WITHDRAWAL' || 'MANUAL_DECREASE':
        return Icons.remove_circle_outline;
      case 'ESCROW_RELEASE' || 'COUPON_PURCHASE':
        return Icons.payments_outlined;
      case 'PENALTY':
        return Icons.warning_amber_outlined;
      case 'COMMISSION_DEDUCTION':
        return Icons.percent;
      case 'PLATFORM_COD_COMMISSION':
        return Icons.percent;
      case 'ORDER_PAYMENT':
        return Icons.credit_card_outlined;
      default:
        return Icons.receipt_long;
    }
  }

  String _getTypeLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (!isArabic) {
      return transaction.type
          .replaceAll('_', ' ')
          .split(' ')
          .map(
            (word) => word[0].toUpperCase() + word.substring(1).toLowerCase(),
          )
          .join(' ');
    }

    switch (transaction.type) {
      case 'TOPUP':
        return l10n.topup;
      case 'WITHDRAWAL':
        return l10n.withdrawal;
      case 'ESCROW_RELEASE':
        return l10n.escrowRelease;
      case 'ESCROW_REMOVE':
        return l10n.escrowRelease;
      case 'COUPON_PURCHASE':
        return l10n.couponRedeemed;
      case 'ESCROW_HOLD':
        return l10n.escrowHold;
      case 'PENALTY':
        return l10n.penalty;
      case 'MANUAL_INCREASE':
        return l10n.topup;
      case 'MANUAL_DECREASE':
        return l10n.withdrawal;
      case 'ORDER_PAYMENT':
        return l10n.cardPaymentReceived;
      default:
        return transaction.type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencyFormatter = NumberFormat.currency(
      symbol: l10n.egp,
      decimalDigits: 2,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
              color: _getTypeColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getTypeIcon(), color: _getTypeColor(), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTypeLabel(context),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  textAlign: TextAlign.start,
                  textDirection: ui.TextDirection.ltr,
                  DateFormat(
                    'dd MMM yyyy, hh:mm a',
                  ).format(transaction.createdAt),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            '${transaction.isPositive ? '+' : '-'} ${currencyFormatter.format(transaction.amount.abs())}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: transaction.isPositive
                  ? Colors.green.shade600
                  : const Color(0xFFE17055),
            ),
          ),
        ],
      ),
    );
  }
}

Widget buildTransactionSkeleton() {
  return Skeletonizer(
    enabled: true,
    effect: const ShimmerEffect(
      baseColor: Color(0xFFE8E8E8),
      highlightColor: Color(0xFFF5F5F5),
      duration: Duration(milliseconds: 1200),
    ),
    child: Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Bone.square(size: 44, borderRadius: BorderRadius.circular(10)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(words: 2, fontSize: 16),
                    const SizedBox(height: 6),
                    Bone.text(words: 4, fontSize: 13),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Bone.text(words: 2, fontSize: 18),
                  const SizedBox(height: 6),
                  Bone(
                    width: 60,
                    height: 20,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Bone.text(words: 3, fontSize: 12),
        ],
      ),
    ),
  );
}
