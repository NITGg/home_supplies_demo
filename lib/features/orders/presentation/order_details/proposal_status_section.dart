import 'package:flutter/material.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/orders_model.dart';

class ProposalStatusSection extends StatelessWidget {
  final OrderModel order;

  const ProposalStatusSection({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (order.proposalHistory == null || order.proposalHistory!.isEmpty) {
      return const SizedBox.shrink();
    }

    final latestProposal = order.proposalHistory!.last;

    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusMessage;

    switch (latestProposal.status) {
      case 'PENDING':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = l10n.offerSubmitted;
        statusMessage = l10n.waitingForCustomerResponse;
        break;
      case 'ACCEPTED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = l10n.offerAccepted;
        statusMessage = l10n.youCanStartDelivery;
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = l10n.offerRejected ?? 'Proposal Rejected';
        statusMessage = l10n.canSubmitAgain ?? 'You can submit a new offer';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [statusColor.withOpacity(0.1), statusColor.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(statusIcon, color: statusColor, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: AppTextStyles.bold18.copyWith(color: statusColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              statusMessage,
              style: AppTextStyles.regular14.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.payments, size: 18, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    '${latestProposal.totalFee} ${l10n.egp}',
                    style: AppTextStyles.bold16.copyWith(color: statusColor),
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