
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/core/style/app_colors.dart';
import 'package:tawreedat_courier/core/utils/logger.dart';
import 'package:tawreedat_courier/features/wallet/presentation/widgets/balance_card.dart';
import 'package:tawreedat_courier/features/wallet/presentation/widgets/commisssion_card.dart';
import 'package:tawreedat_courier/features/wallet/presentation/widgets/empty_section.dart';
import 'package:tawreedat_courier/features/wallet/presentation/widgets/penalty_card.dart';
import 'package:tawreedat_courier/features/wallet/presentation/widgets/quick_action_button.dart';
import 'package:tawreedat_courier/features/wallet/presentation/widgets/section_error.dart';
import 'package:tawreedat_courier/features/wallet/presentation/widgets/section_header.dart';
import 'package:tawreedat_courier/features/wallet/presentation/widgets/transaction_card.dart';
import 'package:tawreedat_courier/features/wallet/presentation/widgets/wallet_shimmer.dart';
import '../../../core/widgets/circel_back_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../coupons/presentation/widgets/active_coupon_banner.dart';
import '../manager/wallet_cubit.dart';
import '../manager/wallet_states.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WalletCubit()
        ..loadWalletData()
        ..loadTransactions(limit: 5)
        ..loadPenalties(limit: 5)
        ..loadUnpaidCommissions(limit: 5),
      child: const WalletView(),
    );
  }
}

class WalletView extends StatelessWidget {
  const WalletView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          l10n.wallet,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: CircleBackButton(
          onPressed: () {
            context.canPop() ? context.pop() : context.go('/mainHome');
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final cubit = context.read<WalletCubit>();
          await Future.wait([
            cubit.loadWalletData(),
            cubit.loadTransactions(limit: 5),
            cubit.loadPenalties(limit: 5),
            cubit.loadUnpaidCommissions(limit: 5),
          ]);
        },
        color: AppColors.kPrimaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Wallet Balance Card
              BlocBuilder<WalletCubit, WalletState>(
                buildWhen: (previous, current) =>
                    current is WalletLoading ||
                    current is WalletLoaded ||
                    current is WalletError,
                builder: (context, state) {
                  if (state is WalletLoading ||
                      (state is! WalletLoaded && state is! WalletError)) {
                    return const BalanceCardShimmer();
                  }

                  if (state is WalletError) {
                    return ErrorCard(
                      message: state.message,
                      onRetry: () =>
                          context.read<WalletCubit>().loadWalletData(),
                    );
                  }

                  if (state is WalletLoaded) {
                    return WalletBalanceCard(
                      points: state.wallet.points ?? 0,
                      balance: state.wallet.balance,
                      isActive: state.wallet.isActive,
                      freezeReason: state.wallet.freezeReason,
                      totalUnpaid: state.totalUnpaidCommission,
                      totalPenalties: state.totalPendingPenalties,
                      availableBalance: state.availableBalance,
                    );
                  }

                  return const BalanceCardShimmer();
                },
              ),

              const SizedBox(height: 28),

              // Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: QuickActionButton(
                        icon: Icons.add_card_rounded,
                        label: l10n.topUp,
                        color: Colors.green.shade600,
                        onTap: () => context.push('/wallet/topup'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: QuickActionButton(
                        icon: Icons.local_offer_rounded,
                        label: l10n.coupons,
                        color: AppColors.kPrimaryColor,
                        onTap: () async {
                          await context.push('/wallet/coupons');
                          if (context.mounted) {
                            final cubit = context.read<WalletCubit>();
                            await Future.wait([
                              cubit.loadWalletData(),
                              cubit.loadTransactions(limit: 5),
                              cubit.loadPenalties(limit: 5),
                              cubit.loadUnpaidCommissions(limit: 5),
                            ]);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ── NEW: Points Button ──
                    Expanded(
                      child: BlocBuilder<WalletCubit, WalletState>(
                        buildWhen: (_, curr) => curr is WalletLoaded || curr is WalletLoading,
                        builder: (context, state) {
                          final points = context.read<WalletCubit>().cachedWallet?.points;
                          final isReady = points != null;
                          return QuickActionButton(
                            icon: isReady ? Icons.stars_rounded : Icons.hourglass_empty_rounded,
                            label: l10n.points,
                            color: isReady ? Colors.amber.shade700 : Colors.grey.shade400,
                            onTap: isReady
                                ? () => context.push('/wallet/points',)
                                : () {}, // no-op while loading
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const ActiveCouponBanner(),
              const SizedBox(height: 32),

              // Recent Transactions Section
              SectionHeader(
                title: l10n.recentTransactions,
                onViewAll: () => context.push('/wallet/transactions'),
              ),

              const SizedBox(height: 12),

              BlocBuilder<WalletCubit, WalletState>(
                buildWhen: (previous, current) =>
                    current is TransactionsLoading ||
                    current is TransactionsLoaded ||
                    current is TransactionsError,
                builder: (context, state) {
                  if (state is TransactionsLoading ||
                      (state is! TransactionsLoaded &&
                          state is! TransactionsError)) {
                    return const SectionCardsShimmer(itemCount: 5);
                  }

                  if (state is TransactionsError) {
                    return SectionError(message: state.message);
                  }

                  if (state is TransactionsLoaded) {
                    if (state.transactions.isEmpty) {
                      return EmptySection(
                        icon: Icons.receipt_long_outlined,
                        message: l10n.noTransactionsYet,
                      );
                    }

                    return Column(
                      children: state.transactions.take(5).map((transaction) {
                        return TransactionCard(transaction: transaction);
                      }).toList(),
                    );
                  }

                  return const SectionCardsShimmer(itemCount: 5);
                },
              ),

              const SizedBox(height: 32),

              // Unpaid Commissions Section
              SectionHeader(
                title: l10n.unpaidCommissions,
                onViewAll: () => context.push('/wallet/unpaid-commissions'),
              ),

              const SizedBox(height: 12),

              BlocBuilder<WalletCubit, WalletState>(
                buildWhen: (previous, current) =>
                    current is UnpaidCommissionsLoading ||
                    current is UnpaidCommissionsLoaded ||
                    current is UnpaidCommissionsError,
                builder: (context, state) {
                  if (state is UnpaidCommissionsLoading ||
                      (state is! UnpaidCommissionsLoaded &&
                          state is! UnpaidCommissionsError)) {
                    return const SectionCardsShimmer(itemCount: 3);
                  }

                  if (state is UnpaidCommissionsError) {
                    return SectionError(message: state.message);
                  }

                  if (state is UnpaidCommissionsLoaded) {
                    dLog(state.commissions.toString());
                    if (state.commissions.isEmpty) {
                      return EmptySection(
                        icon: Icons.verified_outlined,
                        message: l10n.noUnpaidCommissions,
                        isPositive: true,
                      );
                    }

                    final unpaidCommissions = state.commissions
                        .where((c) => !c.isPaid)
                        .take(3)
                        .toList();

                    if (unpaidCommissions.isEmpty) {
                      return EmptySection(
                        icon: Icons.verified_outlined,
                        message: l10n.noUnpaidCommissions,
                        isPositive: true,
                      );
                    }

                    return Column(
                      children: unpaidCommissions.map((commission) {
                        return CommissionCard(commission: commission);
                      }).toList(),
                    );
                  }

                  return const SectionCardsShimmer(itemCount: 3);
                },
              ),

              const SizedBox(height: 32),

              // Penalties Section
              SectionHeader(
                title: l10n.penalties,
                onViewAll: () => context.push('/wallet/penalties'),
              ),

              const SizedBox(height: 12),

              BlocBuilder<WalletCubit, WalletState>(
                buildWhen: (previous, current) =>
                    current is PenaltiesLoading ||
                    current is PenaltiesLoaded ||
                    current is PenaltiesError,
                builder: (context, state) {
                  if (state is PenaltiesLoading ||
                      (state is! PenaltiesLoaded && state is! PenaltiesError)) {
                    return const SectionCardsShimmer(itemCount: 3);
                  }

                  if (state is PenaltiesError) {
                    return SectionError(message: state.message);
                  }

                  if (state is PenaltiesLoaded) {
                    if (state.penalties.isEmpty) {
                      return EmptySection(
                        icon: Icons.verified_outlined,
                        message: l10n.noPenalties,
                        isPositive: true,
                      );
                    }

                    return Column(
                      children: state.penalties.take(3).map((penalty) {
                        return PenaltyCard(penalty: penalty);
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
