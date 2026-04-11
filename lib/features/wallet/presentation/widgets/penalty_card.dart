import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../data/models/transaction_penality_models.dart';


class PenaltyCard extends StatelessWidget {
  final PenaltyModel penalty;

  const PenaltyCard({
    super.key,
    required this.penalty,
  });

  Color _getStatusColor() {
    if (penalty.isWaived) return Colors.blue;
    if (penalty.isPaid) return Colors.green.shade600;
    return const Color(0xFFE17055);
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
        border: Border.all(
          color: _getStatusColor().withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              penalty.isWaived
                  ? Icons.cancel_outlined
                  : penalty.isPaid
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_outlined,
              color: _getStatusColor(),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  penalty.reason ?? l10n.penalty,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  textDirection: ui.TextDirection.ltr,
                  DateFormat('dd MMM yyyy, hh:mm a').format(penalty.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            currencyFormatter.format(penalty.amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(),
            ),
          ),
        ],
      ),
    );
  }
}
