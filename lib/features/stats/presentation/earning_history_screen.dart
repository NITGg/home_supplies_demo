import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../l10n/app_localizations.dart';
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

  void _fetchHistory({bool loadMore = false}) {
    if (loadMore) {
      _currentPage++;
    } else {
      _currentPage = 1;
    }

    context.read<StatsCubit>().fetchEarningsHistory(
      page: _currentPage,
      limit: _limit,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  void _onDateRangeChanged(String? startDate, String? endDate) {
    setState(() {
      _startDate = startDate;
      _endDate = endDate;
    });
    _fetchHistory();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final earningsHistory = context.read<StatsCubit>().earningsHistory;
      if (earningsHistory != null &&
          _currentPage < earningsHistory.pagination.totalPages) {
        _fetchHistory(loadMore: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          isArabic ? 'سجل الأرباح' : 'Earnings History',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: RefreshIndicator(
            onRefresh: () async {
              _fetchHistory();
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Date Range Selector
                      DateRangeSelector(
                        onDateRangeChanged: _onDateRangeChanged,
                        isArabic: isArabic,
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // Transactions List
                BlocBuilder<StatsCubit, StatsState>(
                  builder: (context, state) {
                    final earningsHistory =
                        context.read<StatsCubit>().earningsHistory;

                    if (state is EarningsHistoryLoading &&
                        earningsHistory == null) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (earningsHistory == null ||
                        earningsHistory.transactions.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isArabic
                                    ? 'لا توجد سجلات'
                                    : 'No transactions found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            if (index == earningsHistory.transactions.length) {
                              // Show loading indicator at the bottom
                              if (_currentPage <
                                  earningsHistory.pagination.totalPages) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return const SizedBox(height: 100);
                            }

                            final transaction =
                            earningsHistory.transactions[index];
                            return _buildTransactionCard(
                              context,
                              transaction,
                              isArabic,
                            );
                          },
                          childCount:
                          earningsHistory.transactions.length + 1,
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

  Widget _buildTransactionCard(
      BuildContext context,
      TransactionModel transaction,
      bool isArabic,
      ) {
    final isEarning = transaction.type == 'earning' ||
        transaction.type == 'commission' ||
        transaction.amount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEarning
                  ? const Color(0xFF4CAF50).withOpacity(0.1)
                  : const Color(0xFFF44336).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEarning ? Icons.arrow_downward : Icons.arrow_upward,
              color: isEarning
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFF44336),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a')
                          .format(transaction.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isEarning ? '+' : '-'}${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isEarning
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFF44336),
                ),
              ),
              Text(
                isArabic ? 'ج.م' : 'EGP',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF999999),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}