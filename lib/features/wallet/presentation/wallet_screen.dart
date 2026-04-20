import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/features/wallet/presentation/widgets/penalty_card.dart';
import 'package:tawreedat_go/features/wallet/presentation/widgets/section_header.dart';
import 'package:tawreedat_go/features/wallet/presentation/widgets/transaction_card.dart';
import 'package:tawreedat_go/features/wallet/presentation/widgets/wallet_shimmer.dart';
import '../../../core/widgets/circel_back_cutton.dart';
import '../manager/wallet_cubit.dart';
import '../manager/wallet_state.dart';
import 'widgets/balance_card.dart';
import 'widgets/badge_progress_section.dart';
import 'widgets/empty_section.dart';

import 'widgets/section_error.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<WalletCubit>();
    cubit.fetchWalletData();
    cubit.fetchTransactions(limit: 5);
    cubit.fetchPenalties(limit: 5);
    // cubit.fetchUnpaidCommissions(limit: 5); // if needed
  }

  Future<void> _refreshAll() async {
    final cubit = context.read<WalletCubit>();
    await Future.wait([
      cubit.refreshWalletData(),
      cubit.fetchTransactions(limit: 5),
      cubit.fetchPenalties(limit: 5),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          isArabic ? 'المحفظة' : 'Wallet',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: CircleBackButton(onPressed: (){
          context.canPop() ? context.pop() : context.go('/mainHome');
        },),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: const Color(0xFFFDCB6E),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Wallet Balance Card
              BlocBuilder<WalletCubit, WalletState>(
                buildWhen: (prev, curr) =>
                    curr is WalletLoading ||
                    curr is WalletLoaded ||
                    curr is PenaltiesLoaded ||
                    curr is WalletError,
                builder: (context, state) {
                  if (state is WalletLoading) {
                    return Column(
                      children: [
                        const BalanceCardShimmer(),
                        const SizedBox(height: 24),
                        const BadgeProgressSkeleton(),
                        const SizedBox(height: 24),
                      ],
                    );
                  }
                  if (state is WalletError) {
                    return SectionError(message: state.message);
                  }

                  final cubit = context.read<WalletCubit>();
                  final walletData = cubit.cachedWalletData;

                  if (walletData == null) {
                    return Column(
                      children: [
                        const BalanceCardShimmer(),
                        const SizedBox(height: 24),
                        const BadgeProgressSkeleton(),
                        const SizedBox(height: 24),
                      ],
                    );
                  }

                  final wallet = walletData.wallet;
                  final badge = walletData.badge;
                  final totalFines = cubit.totalPenaltyAmount;

                  return Column(
                    children: [
                      WalletBalanceCard(
                        balance: wallet.balance,
                        isActive: wallet.isActive,
                        points: wallet.points,
                        freezeReason: wallet.freezeReason,
                        totalUnpaid: 0,
                        totalPenalties: totalFines,
                        availableBalance: wallet.balance - totalFines,
                      ),
                      const SizedBox(height: 24),
                      WalletBadgeProgressSection(
                        currentBadge: badge,
                        nextBadge: walletData.nextBadge,
                        completedCount: walletData.completedCount,
                        remainingToNext: walletData.remainingToNext,
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),

              // Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.add_card_rounded,
                        label: isArabic ? 'شحن' : 'TopUp',
                        color: Colors.green.shade600,
                        onTap: () => context.push('/wallet/topup'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Recent Transactions Section
              SectionHeader(
                title: isArabic ? 'أحدث المعاملات' : 'Recent Transactions',
                onViewAll: () => context.push('/wallet/transactions'),
              ),
              const SizedBox(height: 12),
              BlocBuilder<WalletCubit, WalletState>(
                buildWhen: (prev, curr) =>
                    curr is TransactionsLoading ||
                    curr is TransactionsLoaded ||
                    curr is TransactionsError,
                builder: (context, state) {
                  if (state is TransactionsLoading) {
                    return const SectionCardsShimmer(itemCount: 5);
                  }
                  if (state is TransactionsError) {
                    return SectionError(message: state.message);
                  }
                  if (state is TransactionsLoaded) {
                    if (state.transactions.isEmpty) {
                      return EmptySection(
                        icon: Icons.receipt_long_outlined,
                        message: isArabic
                            ? 'لا توجد معاملات بعد'
                            : 'No transactions yet',
                      );
                    }
                    return Column(
                      children: state.transactions.take(5).map((tx) {
                        return TransactionCard(transaction: tx);
                      }).toList(),
                    );
                  }
                  return const SectionCardsShimmer(itemCount: 5);
                },
              ),

              const SizedBox(height: 32),

              // Penalties Section
              SectionHeader(
                title: isArabic ? 'الغرامات' : 'Penalties',
                onViewAll: () => context.push('/wallet/penalties'),
              ),
              const SizedBox(height: 12),
              BlocBuilder<WalletCubit, WalletState>(
                buildWhen: (prev, curr) =>
                    curr is PenaltiesLoading ||
                    curr is PenaltiesLoaded ||
                    curr is PenaltiesError,
                builder: (context, state) {
                  if (state is PenaltiesLoading) {
                    return const SectionCardsShimmer(itemCount: 3);
                  }
                  if (state is PenaltiesError) {
                    return SectionError(message: state.message);
                  }
                  if (state is PenaltiesLoaded) {
                    if (state.penalties.isEmpty) {
                      return EmptySection(
                        icon: Icons.verified_outlined,
                        message: isArabic ? 'لا توجد غرامات' : 'No penalties',
                        isPositive: true,
                      );
                    }
                    return Column(
                      children: state.penalties.take(3).map((p) {
                        return PenaltyCard(penalty: p);
                      }).toList(),
                    );
                  }
                  return const SectionCardsShimmer(itemCount: 3);
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
