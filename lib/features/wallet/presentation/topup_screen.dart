
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../manager/wallet_cubit.dart';
import '../manager/wallet_state.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final TextEditingController _amountController = TextEditingController();
  int? _selectedAmount;

  final List<int> _presetAmounts = [50, 100, 200, 500, 1000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectAmount(int amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  void _onCustomAmountChanged(String value) {
    final parsed = double.tryParse(value) ?? 0;
    setState(() {
      _selectedAmount = parsed.round();
    });
  }

  String? _validateAmount(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedAmount == null || _selectedAmount! <= 0) {
      return l10n.pleaseEnterAmount;
    }
    if (_selectedAmount! < 10) {
      return l10n.minimumTopUpIs;
    }
    if (_selectedAmount! > 5000) {
      return l10n.maximumTopUpIs;
    }
    return null;
  }

  void _showPaymentMethodSelection() {
    final error = _validateAmount(context);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PaymentMethodSheet(
        amount: _selectedAmount!,
        onOnlinePayment: () {
          Navigator.pop(sheetContext);
          // amount_cents = EGP amount * 100
          context.read<WalletCubit>().initiateOnlineTopUp(
            amount: _selectedAmount! * 100,
          );
        },
        onManualTransfer: () {
          Navigator.pop(sheetContext);
          context.push('/wallet/topup/manual', extra: _selectedAmount!);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.topUpWallet,
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
      body: BlocConsumer<WalletCubit, WalletState>(
        listener: (context, state) {
          if (state is TopUpInitiated) {
            context.push(
              '/wallet/topup/payment',
              extra: {
                'paymentUrl': state.response.checkoutUrl,
                'amount': _selectedAmount! * 100,
                'transactionId': state.response.transactionId,
              },
            );
          }
          if (state is TopUpError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is TopUpLoading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.pendingCommissionsWillBeDeducted,
                          style: TextStyle(
                              fontSize: 13, color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  l10n.selectAmount,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _presetAmounts.map((amount) {
                    final isSelected = _selectedAmount == amount;
                    return InkWell(
                      onTap: () => _selectAmount(amount),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.kPrimaryColor
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.kPrimaryColor
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: AppColors.kPrimaryColor
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Text(
                          '$amount ${l10n.egp}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                Text(
                  l10n.orEnterCustomAmount,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                AppTextFormField(
                  label: l10n.amount,
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  onChanged: _onCustomAmountChanged,
                  prefixIcon: const Icon(Icons.payments_rounded),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.pleaseEnterAmount;
                    }
                    if (double.tryParse(value) == null) {
                      return l10n.pleaseEnterValidNumber;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                Text(
                  l10n.minimumTopUp,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 40),

                AppCustomButton(
                  onPressed: _showPaymentMethodSelection,
                  text: l10n.continue_,
                  isLoading: isLoading,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Bottom Sheet & Tile widgets (unchanged from courier app) ──────────────────

class _PaymentMethodSheet extends StatelessWidget {
  final int amount;
  final VoidCallback onOnlinePayment;
  final VoidCallback onManualTransfer;

  const _PaymentMethodSheet({
    required this.amount,
    required this.onOnlinePayment,
    required this.onManualTransfer,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.selectPaymentMethod,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          // const SizedBox(height: 24),
          // _PaymentMethodTile(
          //   asset: 'assets/images/Paymob.jpg',
          //   title: l10n.creditDebitCard,
          //   subtitle: l10n.onlinePayment,
          //   color: AppColors.kSecondaryColor,
          //   onTap: onOnlinePayment,
          // ),
          const SizedBox(height: 12),
          _PaymentMethodTile(
            asset: 'assets/images/InstaPayVodaCash.png',
            title: l10n.mobileWalletInstaPay,
            subtitle: l10n.transferToOurNumbers,
            color: AppColors.kPrimaryColor,
            onTap: onManualTransfer,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String asset;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(asset,
                  fit: BoxFit.cover, width: 40, height: 40),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}