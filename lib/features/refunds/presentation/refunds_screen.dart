import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/formatDate.dart';
import '../../../../l10n/app_localizations.dart';
import '../data/models/refund_model.dart';
import '../data/repo/refund_repo.dart';
import '../manager/refund_cubit.dart';
import '../manager/refund_states.dart';

/// Standalone screen that lists all refund requests for the current customer.
/// Open from the drawer with:
/// ```dart
/// context.push('/refunds');
/// ```
class RefundsScreen extends StatelessWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RefundCubit(repo: RefundRepository())..loadRefunds(),
      child: const _RefundsView(),
    );
  }
}

class _RefundsView extends StatefulWidget {
  const _RefundsView();

  @override
  State<_RefundsView> createState() => _RefundsViewState();
}

class _RefundsViewState extends State<_RefundsView> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      final cubit = context.read<RefundCubit>();
      if (cubit.canLoadMore) cubit.loadRefunds(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.myRefunds, style: AppTextStyles.bold18),
        centerTitle: true,
      ),
      body: BlocBuilder<RefundCubit, RefundState>(
        builder: (context, state) {
          if (state is RefundsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is RefundsError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context.read<RefundCubit>().loadRefunds(),
            );
          }

          if (state is RefundsLoaded) {
            if (state.refunds.isEmpty) {
              return _EmptyView(l10n: l10n);
            }

            return RefreshIndicator(
              color: AppColors.kPrimaryColor,
              onRefresh: () async {
                await context.read<RefundCubit>().loadRefunds();
              },
              child: ListView.builder(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                itemCount: state.refunds.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.refunds.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return _RefundCard(refund: state.refunds[index]);
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ── Refund card ───────────────────────────────────────────────────────────────

class _RefundCard extends StatelessWidget {
  final Refund refund;

  const _RefundCard({required this.refund});

  Color _statusColor() {
    if (refund.isApproved) return Colors.green.shade600;
    if (refund.isRejected) return Colors.red.shade600;
    return Colors.orange.shade600;
  }

  IconData _statusIcon() {
    if (refund.isApproved) return Icons.check_circle_outline;
    if (refund.isRejected) return Icons.cancel_outlined;
    return Icons.schedule_outlined;
  }

  String _statusLabel(AppLocalizations l10n) {
    if (refund.isApproved) return l10n.refundApproved;
    if (refund.isRejected) return l10n.refundRejected;
    return l10n.refundPending;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _statusColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, statusColor.withOpacity(0.03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_statusIcon(), color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.order} #${refund.orderId}',
                          style: AppTextStyles.bold14,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatDate(context, refund.createdAt),
                          style: AppTextStyles.regular14.copyWith(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _statusLabel(l10n),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            // ── Amount ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.monetization_on_outlined,
                    size: 15,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.refundAmount,
                    style: AppTextStyles.regular14.copyWith(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${refund.amount.toStringAsFixed(2)} ${l10n.egp}',
                    style: AppTextStyles.bold14.copyWith(
                      color: AppColors.kPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            // ── Reason ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_outlined,
                    size: 15,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      refund.reason,
                      style: AppTextStyles.regular14.copyWith(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Reviewer note ─────────────────────────────────────────────
            if (refund.rawResponse != null &&
                refund.rawResponse!.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        refund.rawResponse!,
                        style: AppTextStyles.regular14.copyWith(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // ── Evidence images ───────────────────────────────────────────
            if (refund.evidenceImages != null &&
                refund.evidenceImages!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: refund.evidenceImages!.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          refund.evidenceImages![i],
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64,
                            height: 64,
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Empty view ────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyView({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_return_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              l10n.noRefundsYet,
              style: AppTextStyles.bold18.copyWith(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noRefundsYetSubtitle,
              style: AppTextStyles.regular14.copyWith(
                color: Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              message,
              style: AppTextStyles.regular14.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
