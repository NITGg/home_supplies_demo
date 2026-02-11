import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/style/app_colors.dart';
import '../../../../../core/style/text_styles.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/proposal_model.dart';
import '../../../manager/order_cubit.dart';
import '../../../manager/order_states.dart';

class OrderProposalsSheet extends StatefulWidget {
  final Order order;

  const OrderProposalsSheet({super.key, required this.order});

  @override
  State<OrderProposalsSheet> createState() => _OrderProposalsSheetState();
}

class _OrderProposalsSheetState extends State<OrderProposalsSheet> {
  @override
  void initState() {
    super.initState();
    context.read<OrderCubit>().loadProposals(widget.order.id!);
  }

  void _acceptProposal(Proposal proposal) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.acceptProposal),
        content: Text('${l10n.acceptProposalConfirmation} (${proposal.courier.user.fullName}) - ${proposal.totalFee} ${l10n.egp}'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<OrderCubit>().acceptProposal(
                orderId: widget.order.id!,
                proposalId: proposal.id,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: Text(l10n.accept),
          ),
        ],
      ),
    );
  }

  void _rejectProposal(Proposal proposal) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.rejectProposal),
        content: Text(
          '${l10n.rejectProposalConfirmation} (${proposal.courier.user.fullName})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<OrderCubit>().rejectProposal(
                orderId: widget.order.id!,
                proposalId: proposal.id,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.reject),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.proposals, style: AppTextStyles.bold18),
                      Text(
                        widget.order.orderNumber ?? 'N/A',
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Proposals List
          Expanded(
            child: BlocBuilder<OrderCubit, OrderState>(
              builder: (context, state) {
                if (state is ProposalsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ProposalsError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(state.message),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context
                              .read<OrderCubit>()
                              .loadProposals(widget.order.id!),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  );
                }

                if (state is ProposalsLoaded) {
                  if (state.proposals.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noProposalsYet,
                            style: AppTextStyles.regular14.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.couriersWillSendProposalsSoon,
                            style: AppTextStyles.regular14.copyWith(
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.proposals.length,
                    itemBuilder: (context, index) {
                      final proposal = state.proposals[index];
                      return _ProposalCard(
                        proposal: proposal,
                        onAccept: () => _acceptProposal(proposal),
                        onReject: () => _rejectProposal(proposal),
                      );
                    },
                  );
                }

                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final Proposal proposal;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ProposalCard({
    required this.proposal,
    required this.onAccept,
    required this.onReject,
  });

  Color _getStatusColor() {
    if (proposal.isAccepted) return Colors.green;
    if (proposal.isRejected) return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _getStatusColor().withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.kPrimaryColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: AppColors.kPrimaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proposal.courier.user.fullName,
                        style: AppTextStyles.bold16,
                      ),
                      Text(
                        proposal.courier.user.phone,
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    proposal.status,
                    style: AppTextStyles.bold14.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.deliveryFee, style: AppTextStyles.bold14),
                  Text(
                    '${proposal.totalFee} ${l10n.egp}',
                    style: AppTextStyles.bold18.copyWith(
                      color: AppColors.kPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (proposal.isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(l10n.reject),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(l10n.accept),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}