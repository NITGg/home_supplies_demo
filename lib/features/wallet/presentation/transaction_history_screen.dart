import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tawreedat_go/features/wallet/presentation/widgets/date_range.dart';
import 'package:tawreedat_go/features/wallet/presentation/widgets/transaction_card.dart';

import '../../../l10n/app_localizations.dart';
import '../data/data_source/wallet_remote_data_source.dart';
import '../data/models/transaction_penality_models.dart';
import '../data/repositories/wallet_repo.dart';
import '../manager/wallet_cubit.dart';
import '../manager/wallet_state.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WalletCubit(repository: WalletRepository(remoteDataSource: WalletRemoteDataSource()))..fetchTransactions(),
      child: const TransactionHistoryView(),
    );
  }
}

class TransactionHistoryView extends StatefulWidget {
  const TransactionHistoryView({super.key});

  @override
  State<TransactionHistoryView> createState() => _TransactionHistoryViewState();
}

class _TransactionHistoryViewState extends State<TransactionHistoryView> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;

  String? _startDate;
  String? _endDate;
  DateRangePreset _selectedPreset = DateRangePreset.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onDateRangeChanged(
    String? startDate,
    String? endDate,
    DateRangePreset preset,
  ) {
    setState(() {
      _startDate = startDate;
      _endDate = endDate;
      _selectedPreset = preset;
      _currentPage = 1;
    });
    context.read<WalletCubit>().fetchTransactions(
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<WalletCubit>().state;
      if (state is TransactionsLoaded &&
          state.pagination.hasMore &&
          !state.isLoadingMore) {
        _currentPage++;
        context.read<WalletCubit>().fetchTransactions(page: _currentPage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.transactionHistory,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(
          color: Colors.black,
          onPressed: () => context.pop(),
        ),
      ),
      body: Directionality(
        textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: RefreshIndicator(
          onRefresh: () async {
            _currentPage = 1;
            await context.read<WalletCubit>().fetchTransactions(
              startDate: _startDate,
              endDate: _endDate,
            );
          },
          color: const Color(0xFF00B894),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Date selector — always visible ──────────────────────
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    DateRangeSelector(
                      onDateRangeChanged: _onDateRangeChanged,
                      selectedPreset: _selectedPreset,
                      isArabic: isArabic,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ── Content ─────────────────────────────────────────────
              BlocBuilder<WalletCubit, WalletState>(
                builder: (context, state) {
                  // Skeleton on initial load
                  if (state is TransactionsLoading) {
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => buildTransactionSkeleton(),
                          childCount: 7,
                        ),
                      ),
                    );
                  }

                  if (state is TransactionsError) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.errorOccurred,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Text(
                                state.message,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                _currentPage = 1;
                                context.read<WalletCubit>().fetchTransactions(
                                  startDate: _startDate,
                                  endDate: _endDate,
                                );
                              },

                              child: Text(AppLocalizations.of(context)!.retry),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state is TransactionsLoaded) {
                    if (state.transactions.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalizations.of(context)!.noTransactionsYet,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          if (index == state.transactions.length) {
                            if (state.isLoadingMore) {
                              return Column(
                                children: [
                                  buildTransactionSkeleton(),
                                  buildTransactionSkeleton(),
                                  const SizedBox(height: 80),
                                ],
                              );
                            }
                            return const SizedBox(height: 80);
                          }
                          return _TransactionCard(
                            transaction: state.transactions[index],
                            isArabic: isArabic,
                          );
                        }, childCount: state.transactions.length + 1),
                      ),
                    );
                  }

                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final WalletTransactionModel transaction;
  final bool isArabic;

  const _TransactionCard({required this.transaction, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      symbol: AppLocalizations.of(context)!.egp,
      decimalDigits: 2,
    );

    final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

    return Container(
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      textAlign: TextAlign.start,
                      transaction.description??'',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.isPositive ? '+' : ''} ${currencyFormatter.format(transaction.amount)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: transaction.isPositive
                          ? const Color(0xFF00B894)
                          : const Color(0xFFE17055),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusChip(status: transaction.status, isArabic: isArabic),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                textDirection: ui.TextDirection.ltr,
                dateFormatter.format(transaction.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          if (transaction.isFailed && transaction.rejectReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      transaction.rejectReason!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getTypeColor() {
    switch (transaction.type) {
      case 'TOPUP':
        return Colors.green.shade600;
      case 'MANUAL_INCREASE':
        return Colors.green.shade600;
      case 'WITHDRAWAL':
        return const Color(0xFF6C5CE7);
      case 'ESCROW_RELEASE':
        return Colors.green.shade600;
      case 'PENALTY':
        return const Color(0xFFE17055);
      case 'COMMISSION_DEDUCTION':
        return const Color(0xFFFF6B6B);
      case 'PLATFORM_COD_COMMISSION':
        return const Color(0xFFFF6B6B);
      case 'MANUAL_DECREASE':
        return const Color(0xFFFF6B6B);
      case 'COUPON_PURCHASE':
        return const Color(0xFFFF6B6B);
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon() {
    switch (transaction.type) {
      case 'TOPUP' || 'MANUAL_INCREASE':
        return Icons.add_circle_outline;
      case 'WITHDRAWAL' || 'MANUAL_DECREASE' || 'COUPON_PURCHASE':
        return Icons.remove_circle_outline;
      case 'ESCROW_RELEASE':
        return Icons.payments_outlined;
      case 'PENALTY':
        return Icons.warning_amber_outlined;
      case 'COMMISSION_DEDUCTION':
        return Icons.percent;
      case 'PLATFORM_COD_COMMISSION':
        return Icons.percent;
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
        return l10n.escrowRelease;case 'ESCROW_REMOVE':
        return l10n.escrowRelease;
      case 'ESCROW_HOLD':
        return l10n.escrowHold;
      case 'PENALTY':
        return l10n.penalty;
      case 'MANUAL_INCREASE':
        return l10n.topup;
      case 'MANUAL_DECREASE':
        return l10n.withdrawal;
      default:
        return transaction.type;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isArabic;

  const _StatusChip({required this.status, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'COMPLETED':
        backgroundColor = const Color(0xFF00B894).withOpacity(0.1);
        textColor = const Color(0xFF00B894);
        label = AppLocalizations.of(context)!.done;
        break;
      case 'PENDING':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange.shade700;
        label = AppLocalizations.of(context)!.pending;
        break;
      case 'FAILED':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red.shade700;
        label = AppLocalizations.of(context)!.failed;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
