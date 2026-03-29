import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/widgets/image_with_fallback.dart';

import '../../../../../core/style/app_colors.dart';
import '../../../../../core/style/text_styles.dart';
import '../../../../../core/utils/phone_dialer.dart';
import '../../../../../core/utils/socket_service.dart';
import '../../../../../core/widgets/loading_screen.dart';
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
  StreamSubscription? _newOfferSubscription;
  List<Proposal> _currentProposals = [];
  bool _isInitialLoad = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    context.read<OrderCubit>().loadProposals(widget.order.id!);
    _setupSocketListener();
  }

  @override
  void dispose() {
    _newOfferSubscription?.cancel();
    super.dispose();
  }

  void _setupSocketListener() {
    final socketService = SocketService();

    if (!socketService.isConnected) return;

    // Subscribe to new offers, filtering for this specific order
    _newOfferSubscription = socketService.onNewOffer.listen((data) {
      final orderId = data['orderId'] as int?;

      if (mounted && orderId == widget.order.id) {
        _handleNewOffer();
      }
    });
  }

  void _handleNewOffer() {
    final l10n = AppLocalizations.of(context)!;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.refresh, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              l10n.newProposalReceived ?? 'New proposal received!',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Set refreshing flag and reload proposals
    setState(() {
      _isRefreshing = true;
    });

    context.read<OrderCubit>().loadProposals(widget.order.id!);
  }

  void _acceptProposal(Proposal proposal) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.acceptProposal,
                style: AppTextStyles.bold18.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.acceptProposalConfirmation,
              style: AppTextStyles.regular14.copyWith(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          proposal.courier.user.fullName,
                          style: AppTextStyles.bold14.copyWith(
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        size: 18,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${proposal.totalFee} ${l10n.egp}',
                        style: AppTextStyles.bold16.copyWith(
                          color: Colors.green,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              l10n.cancel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<OrderCubit>().acceptProposal(
                orderId: widget.order.id!,
                proposalId: proposal.id,
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check, size: 18),
            label: Text(
              l10n.accept,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cancel, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.rejectProposal,
                style: AppTextStyles.bold18.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.rejectProposalConfirmation,
              style: AppTextStyles.regular14.copyWith(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      proposal.courier.user.fullName,
                      style: AppTextStyles.bold14.copyWith(
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              l10n.cancel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<OrderCubit>().rejectProposal(
                orderId: widget.order.id!,
                proposalId: proposal.id,
              );
            },
            icon: const Icon(Icons.close, size: 18),
            label: Text(
              l10n.reject,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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
                      Row(
                        children: [
                          Text(l10n.proposals, style: AppTextStyles.bold18),
                          const SizedBox(width: 8),
                          // Show refresh indicator when refreshing
                          if (_isRefreshing)
                            CircularProgressIndicator(
                              color: AppColors.kPrimaryColor,
                              strokeWidth: 2,
                            ),
                        ],
                      ),
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
            child: BlocConsumer<OrderCubit, OrderState>(
              listener: (context, state) {
                // Update cached proposals and reset flags when loaded
                if (state is ProposalsLoaded) {
                  setState(() {
                    _currentProposals = state.proposals;
                    _isInitialLoad = false;
                    _isRefreshing = false;
                  });
                }
              },
              buildWhen: (previous, current) {
                // Only rebuild on initial load, not on refresh
                return _isInitialLoad &&
                    (current is ProposalsLoading ||
                        current is ProposalsLoaded ||
                        current is ProposalsError);
              },
              builder: (context, state) {
                // Show loading only on initial load
                if (_isInitialLoad && state is ProposalsLoading) {
                  return const Center(
                    child: LoadingScreen(isOne: true, asWidget: true),
                  );
                }

                // Show error state
                if (state is ProposalsError && _currentProposals.isEmpty) {
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
                          onPressed: () {
                            setState(() {
                              _isInitialLoad = true;
                            });
                            context.read<OrderCubit>().loadProposals(
                              widget.order.id!,
                            );
                          },
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  );
                }

                // Show cached proposals (or loaded proposals)
                final proposals = state is ProposalsLoaded
                    ? state.proposals
                    : _currentProposals;

                if (proposals.isEmpty) {
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
                  itemCount: proposals.length,
                  itemBuilder: (context, index) {
                    final proposal = proposals[index];
                    return _ProposalCard(
                      proposal: proposal,
                      onAccept: () => _acceptProposal(proposal),
                      onReject: () => _rejectProposal(proposal),
                    );
                  },
                );
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

  String _getStatusText(context) {
    if (proposal.isAccepted) return AppLocalizations.of(context)!.accepted;
    if (proposal.isRejected) return AppLocalizations.of(context)!.rejected;
    return AppLocalizations.of(context)!.pending;
  }

  IconData _getStatusIcon() {
    if (proposal.isAccepted) return Icons.check_circle;
    if (proposal.isRejected) return Icons.cancel;
    return Icons.schedule;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _getStatusColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shadowColor: statusColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, statusColor.withOpacity(0.03)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, l10n, statusColor),
            _buildFeeSection(context, l10n),
            if (proposal.isPending) _buildActionButtons(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    Color statusColor,
  ) {
    return GestureDetector(
      onTap: () => openPhoneApp(proposal.courier.user.phone),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.07),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.kPrimaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.kPrimaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(Icons.person, color: AppColors.kPrimaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proposal.courier.user.fullName,
                    style: AppTextStyles.bold16.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        textDirection: TextDirection.ltr,
                        proposal.courier.user.phone,
                        style: AppTextStyles.regular14.copyWith(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getStatusIcon(), size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusText(context),
                    style: AppTextStyles.bold14.copyWith(
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _distanceLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (proposal.distanceToPickupM >= 1000) {
      return '${(proposal.distanceToPickupM / 1000).toStringAsFixed(1)} ${l10n.km}';
    }
    return '${proposal.distanceToPickupM.toStringAsFixed(0)} ${l10n.m}';
  }

  Widget _buildFeeSection(BuildContext context, AppLocalizations l10n) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final vehicleName = isArabic
        ? proposal.vehicle.nameAr
        : proposal.vehicle.name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // ── Vehicle + distance row ──────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                // Vehicle icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ImageWithIconFallback(imageUrl: proposal.vehicle.icon,height: 32,                    fit: BoxFit.contain,
                  )
                ),
                const SizedBox(width: 10),
                // Vehicle name
                Expanded(
                  child: Text(
                    vehicleName,
                    style: AppTextStyles.bold14.copyWith(
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                // Distance to pickup badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.kPrimaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.kPrimaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.far,
                        style: AppTextStyles.bold14.copyWith(
                          fontSize: 12,
                          color: AppColors.kPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _distanceLabel(context),
                        style: AppTextStyles.bold14.copyWith(
                          fontSize: 12,
                          color: AppColors.kPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Fee row ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.kPrimaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 8),
                    Text(
                      l10n.deliveryFee,
                      style: AppTextStyles.bold14.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${proposal.totalFee} ${l10n.egp}',
                  style: AppTextStyles.bold18.copyWith(
                    color: AppColors.kPrimaryColor,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(
                    l10n.reject,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    l10n.accept,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
