import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tawreedat_go/features/wallet/data/data_source/wallet_remote_data_source.dart';
import 'package:tawreedat_go/features/wallet/data/repositories/wallet_repo.dart';

import '../../../core/widgets/loading_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/transaction_penality_models.dart';
import '../manager/wallet_cubit.dart';
import '../manager/wallet_state.dart';


class PenaltiesScreen extends StatelessWidget {
  const PenaltiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WalletCubit(repository: WalletRepository(remoteDataSource: WalletRemoteDataSource()))..fetchPenalties(),
      child: const PenaltiesView(),
    );
  }
}

class PenaltiesView extends StatefulWidget {
  const PenaltiesView({super.key});

  @override
  State<PenaltiesView> createState() => _PenaltiesViewState();
}

class _PenaltiesViewState extends State<PenaltiesView> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
      if (state is PenaltiesLoaded &&
          state.pagination.hasMore &&
          !state.isLoadingMore) {
        _currentPage++;
        context.read<WalletCubit>().fetchPenalties(page: _currentPage);
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
          AppLocalizations.of(context)!.penalties,
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
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, state) {
          if (state is PenaltiesLoading) {
            return const Center(
              child: LoadingScreen(isOne: true,),
            );
          }

          if (state is PenaltiesError) {
            return Center(
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
                    padding: const EdgeInsets.symmetric(horizontal: 32),
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
                      context.read<WalletCubit>().fetchPenalties();
                    },
                    child: Text(AppLocalizations.of(context)!.retry),
                  ),
                ],
              ),
            );
          }

          if (state is PenaltiesLoaded) {
            if (state.penalties.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 80,
                      color: Colors.green.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.noPenalties,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.youreInGoodStanding,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                _currentPage = 1;
                await context.read<WalletCubit>().fetchPenalties();
              },
              color: const Color(0xFFE17055),
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount:
                state.penalties.length + (state.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.penalties.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE17055),
                        ),
                      ),
                    );
                  }

                  final penalty = state.penalties[index];
                  return _PenaltyCard(
                    penalty: penalty,
                    isArabic: isArabic,
                  );
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

class _PenaltyCard extends StatelessWidget {
  final PenaltyModel penalty;
  final bool isArabic;

  const _PenaltyCard({
    required this.penalty,
    required this.isArabic,
  });

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
        border: Border.all(
          color: _getStatusColor().withOpacity(0.3),
          width: 1.5,
        ),
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
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getStatusIcon(),
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
                      penalty.reason ?? (AppLocalizations.of(context)!.penalty),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (penalty.orderId != null)
                      Text(
                        '${AppLocalizations.of(context)!.order} #${penalty.orderId}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '- ${currencyFormatter.format(penalty.amount)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusChip(
                    status: penalty.statusText,
                    isArabic: isArabic,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                textDirection: ui.TextDirection.ltr,
                dateFormatter.format(penalty.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          if (penalty.isPaid && penalty.paidAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${AppLocalizations.of(context)!.paidDate} ${dateFormatter.format(penalty.paidAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ],
          if (penalty.isWaived && penalty.waivedAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.cancel,
                  size: 14,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${AppLocalizations.of(context)!.waivedDate} ${dateFormatter.format(penalty.waivedAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (penalty.isWaived) return Colors.blue;
    if (penalty.isPaid) return const Color(0xFF00B894);
    return const Color(0xFFE17055);
  }

  IconData _getStatusIcon() {
    if (penalty.isWaived) return Icons.cancel_outlined;
    if (penalty.isPaid) return Icons.check_circle_outline;
    return Icons.warning_amber_outlined;
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isArabic;

  const _StatusChip({
    required this.status,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'COMPLETED':
        backgroundColor = const Color(0xFF00B894).withOpacity(0.1);
        textColor = const Color(0xFF00B894);
        label = AppLocalizations.of(context)!.paid;
        break;
      case 'PENDING':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange.shade700;
        label = AppLocalizations.of(context)!.pending;
        break;
      case 'WAIVED':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue.shade700;
        label = AppLocalizations.of(context)!.waived;
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