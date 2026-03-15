import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/widgets/loading_screen.dart';
import '../manager/wallet_cubit.dart';
import '../manager/wallet_state.dart';
import 'badge_progress_section.dart';
import 'balance_card.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    context.read<WalletCubit>().fetchWalletData();
  }

  Future<void> _refreshWalletData() async {
    await context.read<WalletCubit>().refreshWalletData();
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
        leading: BackButton(
          color: Colors.black,
          onPressed: () =>
          context.canPop() ? context.pop() : context.go('/mainHome'),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(child: LoadingScreen(isOne: true));
          }

          if (state is WalletError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red.withOpacity(0.7),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<WalletCubit>().fetchWalletData();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is TopUpInitiated ||
              state is TopUpLoading ||
              state is TopUpError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<WalletCubit>().fetchWalletData();
            });
            return const Center(child: CircularProgressIndicator());
          }

          if (state is WalletLoaded) {
            final walletData = state.walletData;
            final wallet = walletData.wallet;
            final badge = walletData.badge;

            return RefreshIndicator(
              onRefresh: _refreshWalletData,
              color: const Color(0xFFFDCB6E),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Wallet Balance Card
                    WalletBalanceCard(
                      balance: wallet.balance,
                      isActive: wallet.isActive,
                      points:wallet.points,
                      freezeReason: wallet.freezeReason,
                      totalUnpaid: 0,
                      totalPenalties: 0,
                      availableBalance: wallet.balance,
                    ),

                    const SizedBox(height: 24),

                    // Badge Progress Section
                    WalletBadgeProgressSection(
                      currentBadge: badge,
                      nextBadge: walletData.nextBadge,
                      completedCount: walletData.completedCount,
                      remainingToNext: walletData.remainingToNext,
                    ),

                    const SizedBox(height: 24),

                    // Quick Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        spacing: 20,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.add_card_rounded,
                                  label: isArabic ? 'شحن' : 'TopUp',
                                  color: Colors.green.shade600,
                                  onTap: () => context.push('/wallet/topup'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }

          // Initial state
          return const SizedBox.shrink();
        },
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
