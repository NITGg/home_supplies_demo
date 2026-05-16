import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/widgets/image_with_fallback.dart';

import '../../../../../core/style/app_colors.dart';
import '../../../../../core/style/text_styles.dart';
import '../../../../../core/utils/phone_dialer.dart';
import '../../../../../core/utils/socket_service.dart';
import '../../../../../core/widgets/banners.dart';
import '../../../../../core/widgets/egy_plate.dart';
import '../../../../../core/widgets/loading_screen.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/proposal_model.dart';
import '../../../manager/order_cubit.dart';
import '../../../manager/order_states.dart';
import 'create_order_sheet/insufficient_balance_sheet.dart';

enum _SortOption { none, feeAsc, feeDesc, distanceAsc, distanceDesc }

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
  _SortOption _sortOption = _SortOption.none;

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

    _newOfferSubscription = socketService.onNewOffer.listen((data) {
      final orderId = data['orderId'] as int?;
      if (mounted && orderId == widget.order.id) _handleNewOffer();
    });
  }

  void _handleNewOffer() {
    final l10n = AppLocalizations.of(context)!;

    showSuccessBanner(
      context,
      l10n.newProposalReceived ?? 'New proposal received!',
    );

    setState(() => _isRefreshing = true);
    context.read<OrderCubit>().loadProposals(widget.order.id!);
  }

  List<Proposal> _sorted(List<Proposal> proposals) {
    final list = [...proposals];
    switch (_sortOption) {
      case _SortOption.feeAsc:
        list.sort((a, b) => (a.totalFee).compareTo(b.totalFee));
      case _SortOption.feeDesc:
        list.sort((a, b) => (b.totalFee).compareTo(a.totalFee));
      case _SortOption.distanceAsc:
        list.sort((a, b) => a.distanceToPickupM.compareTo(b.distanceToPickupM));
      case _SortOption.distanceDesc:
        list.sort((a, b) => b.distanceToPickupM.compareTo(a.distanceToPickupM));
      case _SortOption.none:
        break;
    }

    // ✅ Always push rejected to the bottom, regardless of sort option
    list.sort((a, b) {
      final aRejected = a.isRejected ? 1 : 0;
      final bRejected = b.isRejected ? 1 : 0;
      return aRejected.compareTo(bRejected);
    });

    return list;
  }

  void _cycleFeeSort() {
    setState(() {
      _sortOption = _sortOption == _SortOption.feeAsc
          ? _SortOption.feeDesc
          : _SortOption.feeAsc;
    });
  }

  void _cycleDistanceSort() {
    setState(() {
      _sortOption = _sortOption == _SortOption.distanceAsc
          ? _SortOption.distanceDesc
          : _SortOption.distanceAsc;
    });
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
                border: Border.all(color: Colors.green.withOpacity(0.2)),
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
                      // ── Discount-aware fee display ──────────────────────────────────────────
                      Builder(
                        builder: (_) {
                          final hasDiscount = proposal.discountFee > 0;
                          final discountedCourierFee = (proposal.courierFee - proposal.discountFee)
                              .clamp(0.0, double.infinity);
                          final total = discountedCourierFee + proposal.platformFee;
                          final originalTotal = proposal.courierFee + proposal.platformFee;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_balance_wallet, size: 18, color: Colors.green),
                              const SizedBox(width: 8),
                              if (hasDiscount) ...[
                                Text(
                                  '${originalTotal.toStringAsFixed(2)} ${l10n.egp}',
                                  style: AppTextStyles.bold14.copyWith(
                                    fontSize: 13,
                                    color: Colors.red.shade300,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.red.shade300,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                '${(hasDiscount ? total : originalTotal).toStringAsFixed(2)} ${l10n.egp}',
                                style: AppTextStyles.bold16.copyWith(
                                  color: Colors.green,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          );
                        },
                      ),                      // ───────────────────────────────────────────────────────────
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
                border: Border.all(color: Colors.red.withOpacity(0.2)),
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
                          if (_isRefreshing)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: AppColors.kPrimaryColor,
                                strokeWidth: 2,
                              ),
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

          // ── Sort chips ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                _SortChip(
                  label: l10n.deliveryFee,
                  icon: Icons.account_balance_wallet_outlined,
                  isActive:
                      _sortOption == _SortOption.feeAsc ||
                      _sortOption == _SortOption.feeDesc,
                  ascending: _sortOption == _SortOption.feeAsc,
                  onTap: _cycleFeeSort,
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: l10n.nearMe,
                  icon: Icons.near_me_rounded,
                  isActive:
                      _sortOption == _SortOption.distanceAsc ||
                      _sortOption == _SortOption.distanceDesc,
                  ascending: _sortOption == _SortOption.distanceAsc,
                  onTap: _cycleDistanceSort,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Proposals list
          Expanded(
            child: BlocConsumer<OrderCubit, OrderState>(
              // In the BlocConsumer listener inside the Expanded proposals list:
              listener: (context, state) {
                if (state is ProposalsLoaded) {
                  setState(() {
                    _currentProposals = state.proposals;
                    _isInitialLoad = false;
                    _isRefreshing = false;
                  });
                }
                if (state is ProposalAccepted) {
                  Navigator.pop(context);
                }

                // ── NEW: insufficient balance after accepting ──────────────────
                if (state is ProposalAcceptInsufficientBalance) {
                  final l10n = AppLocalizations.of(context)!;
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => InsufficientBalanceSheet(
                      currentBalance: state.current,
                      requiredAmount: state.required,
                      shortfall: (state.required - state.current).clamp(
                        0,
                        double.infinity,
                      ),
                      isShopping: false,
                      l10n: l10n,
                      onTopUp: () async {
                        Navigator.pop(context); // close sheet
                        await context.push('/wallet/topup');
                      },
                    ),
                  );
                }
              },
              buildWhen: (previous, current) {
                return _isInitialLoad &&
                    (current is ProposalsLoading ||
                        current is ProposalsLoaded ||
                        current is ProposalsError);
              },
              builder: (context, state) {
                if (_isInitialLoad && state is ProposalsLoading) {
                  return const Center(
                    child: LoadingScreen(isOne: true, asWidget: true),
                  );
                }

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
                            setState(() => _isInitialLoad = true);
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

                final raw = state is ProposalsLoaded
                    ? state.proposals
                    : _currentProposals;
                final proposals = _sorted(raw);

                if (proposals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
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
                      key: ValueKey(proposal.id),
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

// ── Sort chip ─────────────────────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool ascending;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.kPrimaryColor
              : AppColors.kPrimaryColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.kPrimaryColor
                : AppColors.kPrimaryColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : AppColors.kPrimaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bold14.copyWith(
                fontSize: 12,
                color: isActive ? Colors.white : AppColors.kPrimaryColor,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                ascending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 13,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Proposal card (expandable) ────────────────────────────────────────────────

class _ProposalCard extends StatefulWidget {
  final Proposal proposal;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ProposalCard({
    super.key,
    required this.proposal,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends State<_ProposalCard> {
  bool _expanded = false;

  Color _getStatusColor() {
    if (widget.proposal.isAccepted) return Colors.green;
    if (widget.proposal.isRejected) return Colors.red;
    return Colors.orange;
  }

  String _getStatusText(BuildContext context) {
    if (widget.proposal.isAccepted) {
      return AppLocalizations.of(context)!.accepted;
    }
    if (widget.proposal.isRejected) {
      return AppLocalizations.of(context)!.rejected;
    }
    return AppLocalizations.of(context)!.pending;
  }

  IconData _getStatusIcon() {
    if (widget.proposal.isAccepted) return Icons.check_circle;
    if (widget.proposal.isRejected) return Icons.cancel;
    return Icons.schedule;
  }

  String _distanceLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.proposal.distanceToPickupM >= 1000) {
      return '${(widget.proposal.distanceToPickupM / 1000).toStringAsFixed(1)} ${l10n.km}';
    }
    return '${widget.proposal.distanceToPickupM.toStringAsFixed(0)} ${l10n.m}';
  }

  String _formatDuration(int seconds, AppLocalizations l10n) {
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins ${l10n.min}';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h${l10n.hour}' : '$h${l10n.hour} $m${l10n.min}';
  }

  @override
  Widget build(BuildContext context) {
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
            // ── Collapsed header — always visible, tap to expand ──
            _buildHeader(context, statusColor),

            // ── Expandable body ───────────────────────────────────
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const Divider(height: 1),
                  _buildFeeSection(context),
                  if (widget.proposal.isPending) _buildActionButtons(context),
                ],
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color statusColor) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      borderRadius: _expanded
          ? const BorderRadius.vertical(top: Radius.circular(16))
          : BorderRadius.circular(16),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.07),
          borderRadius: _expanded
              ? const BorderRadius.vertical(top: Radius.circular(16))
              : BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                // Phone tap area
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: GestureDetector(
                    onTap: () =>
                        openPhoneApp(widget.proposal.courier.user.phone),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(Icons.phone, color: statusColor, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: ImageWithIconFallback(
                    imageUrl: widget.proposal.courier.user.personalPhoto,
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                    iconSize: 20,),
                ),
                const SizedBox(width: 8),

                // Name + quick info row
                Expanded(
                  child: Text(
                    widget.proposal.courier.user.fullName,
                    style: AppTextStyles.bold14.copyWith(fontSize: 12),
                  ),
                ),

                const SizedBox(width: 8),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getStatusIcon(), size: 11, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        _getStatusText(context),
                        style: AppTextStyles.bold14.copyWith(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Expand chevron
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Fee + distance inline preview
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 3),
                Text(
                  () {
                    final discount = widget.proposal.discountFee ?? 0;
                    final finalFee = (widget.proposal.courierFee - discount)
                        .clamp(0, double.infinity);
                    return '${(finalFee + widget.proposal.platformFee).toStringAsFixed(2)} ${l10n.egp}';
                  }(),
                  style: AppTextStyles.bold14.copyWith(
                    fontSize: 13,
                    color: (widget.proposal.discountFee ?? 0) > 0
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.near_me_rounded,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 3),
                Text(
                  _distanceLabel(context),
                  style: AppTextStyles.regular14.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.timer, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Text(
                  _formatDuration(widget.proposal.timeToPickup, l10n),
                  style: AppTextStyles.regular14.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final vehicleName = isArabic
        ? widget.proposal.vehicle.nameAr
        : widget.proposal.vehicle.name;
    final courierFee = widget.proposal.courierFee;
    final discount = widget.proposal.discountFee;
    final hasDiscount = discount > 0;
    final discountedCourierFee = (courierFee - discount).clamp(
      0.0,
      double.infinity,
    );
    final platformFee = widget.proposal.platformFee;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Vehicle + distance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: ImageWithIconFallback(
                        imageUrl: widget.proposal.vehicle.icon,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 20),

                    Expanded(
                      child: Text(
                        vehicleName,
                        style: AppTextStyles.bold14.copyWith(
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    if (widget.proposal.courier.courierVehiclePlate != 'N/A')
                      EgyptianPlate(
                        plateNumber:
                            widget.proposal.courier.courierVehiclePlate,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            widget.proposal.courier.courierRate.toString(),
                            style: AppTextStyles.bold14.copyWith(
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Icon(Icons.star_half, color: Colors.yellow),
                        ],
                      ),
                    ),

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
                            _formatDuration(widget.proposal.timeToPickup, l10n),
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
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Courier / delivery fee ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.kPrimaryColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.deliveryFee,
                  style: AppTextStyles.bold14.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                if (!hasDiscount)
                  Text(
                    '${courierFee.toStringAsFixed(2)} ${l10n.egp}',
                    style: AppTextStyles.bold18.copyWith(
                      color: AppColors.kPrimaryColor,
                      fontSize: 20,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${courierFee.toStringAsFixed(2)} ${l10n.egp}',
                        style: AppTextStyles.bold14.copyWith(
                          fontSize: 13,
                          color: Colors.red.shade400,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${discountedCourierFee.toStringAsFixed(2)} ${l10n.egp}',
                        style: AppTextStyles.bold18.copyWith(
                          color: Colors.green.shade700,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Platform / service fee ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.kPrimaryColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.serviceFee,
                  style: AppTextStyles.bold14.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  '${platformFee.toStringAsFixed(2)} ${l10n.egp}',
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

  Widget _buildActionButtons(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onReject,
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
                  onPressed: widget.onAccept,
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
