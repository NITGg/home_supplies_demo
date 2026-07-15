import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/banners.dart';
import '../../../core/widgets/circel_back_button.dart';
import '../../stats/manager/stats_cubit.dart';
import '../../stats/manager/stats_states.dart';
import '../../stats/data/models/stats_models.dart';
import '../../stats/presentation/widgets/date_range_selector.dart';

class EarningsHistoryScreen extends StatefulWidget {
  const EarningsHistoryScreen({super.key});

  @override
  State<EarningsHistoryScreen> createState() => _EarningsHistoryScreenState();
}

class _EarningsHistoryScreenState extends State<EarningsHistoryScreen> {
  String? _startDate;
  String? _endDate;
  final int _limit = 20;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory({bool loadMore = false}) {
    if (loadMore) {
      _currentPage++;
    } else {
      _currentPage = 1;
    }

    return context.read<StatsCubit>().fetchEarningsHistory(
      page: _currentPage,
      limit: _limit,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  void _onDateRangeChanged(String? startDate, String? endDate, DateRangePreset preset) { // ← add preset
    setState(() {
      _startDate = startDate;
      _endDate = endDate;
    });
    _fetchHistory();
  }

  bool _isLoadingMore = false;

  void _onScroll() {
    if (_isLoadingMore) return; // ← guard against rapid firing

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final earningsHistory = context.read<StatsCubit>().earningsHistory;
      if (earningsHistory != null &&
          _currentPage < earningsHistory.pagination.totalPages) {
        _isLoadingMore = true;
        _fetchHistory(loadMore: true).whenComplete(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: CircleBackButton(),
        title: Text(
          AppLocalizations.of(context)!.earningsHistory,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: BlocListener<StatsCubit, StatsState>(
          listener: (context, state) {
            if (state is StatsFailure) {
              showErrorBanner(context, state.message);
            }
          },
          child: RefreshIndicator(
            onRefresh: () async => _fetchHistory(),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      DateRangeSelector(
                        onDateRangeChanged: _onDateRangeChanged,
                        isArabic: isArabic,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                BlocBuilder<StatsCubit, StatsState>(
                  builder: (context, state) {
                    final earningsHistory =
                        context.read<StatsCubit>().earningsHistory;

                    final isInitialLoading =
                        state is EarningsHistoryLoading &&
                            earningsHistory == null;

                    // Shimmer skeleton on initial load
                    if (isInitialLoading) {
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildTransactionSkeleton(),
                            childCount: 7,
                          ),
                        ),
                      );
                    }

                    if (earningsHistory == null || earningsHistory.transactions
                        .where((tx) => tx.courierFee > 0).isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                  AppLocalizations.of(context)!.noTransactionsYet,
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final filteredTransactions = earningsHistory.transactions
                        .where((tx) => tx.courierFee > 0)
                        .toList();
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            if (index == filteredTransactions.length) {
                              // Skeleton rows while paginating
                              if (_isLoadingMore) {
                                return Column(
                                  children: [
                                    _buildTransactionSkeleton(),
                                    _buildTransactionSkeleton(),
                                    const SizedBox(height: 100),
                                  ],
                                );
                              }
                              return const SizedBox(height: 100);
                            }

                            final transaction =
                            filteredTransactions[index];
                            return _buildTransactionCard(
                              context,
                              transaction,
                              isArabic,
                            );
                          },
                          childCount: filteredTransactions.length + 1,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shimmer skeleton — mirrors the real card layout
  // ---------------------------------------------------------------------------

  Widget _buildTransactionSkeleton() {
    return Skeletonizer(
      enabled: true,
      effect: const ShimmerEffect(
        baseColor: Color(0xFFE8E8E8),
        highlightColor: Color(0xFFF5F5F5),
        duration: Duration(milliseconds: 1200),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar skeleton
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Bone(
                      width: 84,
                      height: 24,
                      borderRadius: BorderRadius.circular(20)),
                  const SizedBox(width: 8),
                  Expanded(child: Bone.text(words: 2, fontSize: 12)),
                  const SizedBox(width: 8),
                  Bone.text(words: 1, fontSize: 18),
                  const SizedBox(width: 4),
                  Bone.text(words: 1, fontSize: 12),
                ],
              ),
            ),
            // Body skeleton
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route row
                  Row(
                    children: [
                      Bone.square(
                          size: 15, borderRadius: BorderRadius.circular(8)),
                      const SizedBox(width: 6),
                      Expanded(child: Bone.text(words: 2, fontSize: 13)),
                      const SizedBox(width: 16),
                      Bone.square(
                          size: 15, borderRadius: BorderRadius.circular(8)),
                      const SizedBox(width: 4),
                      Expanded(child: Bone.text(words: 2, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Date row
                  Bone.text(words: 5, fontSize: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Real transaction card
  // ---------------------------------------------------------------------------

  Widget _buildTransactionCard(
      BuildContext context,
      TransactionModel tx,
      bool isArabic,
      ) {
    final pickupName = isArabic ? tx.pickupAreaNameAr : tx.pickupAreaName;
    final deliveryName =
    isArabic ? tx.deliveryAreaNameAr : tx.deliveryAreaName;

    final Color statusColor =
    tx.isDelivered ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final String statusLabel = tx.isDelivered
        ? AppLocalizations.of(context)!.delivered
        : AppLocalizations.of(context)!.cancelled;
    final IconData statusIcon =
    tx.isDelivered ? Icons.check_circle : Icons.cancel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header bar ────────────────────────────────────────────────
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Order number
                Expanded(
                  child: Text(
                    tx.orderNumber,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF999999),
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Courier earnings
                Text(
                  '+${(tx.courierFee/100).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: tx.isDelivered
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF999999),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context)!.egp,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route: pickup → delivery
                Row(
                  children: [
                    const Icon(Icons.radio_button_checked,
                        size: 15, color: Color(0xFF2196F3)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        pickupName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward,
                          size: 14, color: Color(0xFF999999)),
                    ),
                    const Icon(Icons.location_on,
                        size: 15, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        deliveryName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Fee breakdown — only for delivered orders
                if (tx.isDelivered) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildFeeChip(
                          label: AppLocalizations.of(context)!.totalFee,
                          value: tx.totalFee/100,
                          color: const Color(0xFF1A1A1A),
                          isArabic: isArabic,
                        ),
                        _buildVerticalDivider(),
                        _buildFeeChip(
                          label: AppLocalizations.of(context)!.courier,
                          value: tx.courierFee/100,
                          color: const Color(0xFF4CAF50),
                          isArabic: isArabic,
                        ),
                        _buildVerticalDivider(),
                        _buildFeeChip(
                          label: AppLocalizations.of(context)!.platform,
                          value: tx.platformFee/100,
                          color: Colors.orangeAccent,
                          isArabic: isArabic,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Created at + delivered at
                Row(
                  children: [
                    Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      textDirection: ui.TextDirection.ltr,
                      DateFormat('dd MMM yyyy, hh:mm a')
                          .format(tx.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (tx.isDelivered && tx.deliveredAt != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.done_all,
                          size: 13,
                          color: const Color(0xFF4CAF50).withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Text(
                        textDirection: ui.TextDirection.ltr,
                        DateFormat('hh:mm a').format(tx.deliveredAt!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeChip({
    required String label,
    required num value,
    required Color color,
    required bool isArabic,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 2),
          Text(
            '${value.toStringAsFixed(2)} ${AppLocalizations.of(context)!.egp}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0xFFE0E0E0),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}