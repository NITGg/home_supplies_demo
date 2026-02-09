import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/orders_cubit.dart';
import '../../manager/orders_states.dart';

/// Reusable bottom sheet for canceling orders
class OrderCancelBottomSheet extends StatefulWidget {
  final bool isUnavailable;
  final int orderId;

  const OrderCancelBottomSheet({
    super.key,
    required this.isUnavailable,
    required this.orderId,
  });

  @override
  State<OrderCancelBottomSheet> createState() => _OrderCancelBottomSheetState();
}

class _OrderCancelBottomSheetState extends State<OrderCancelBottomSheet> {
  final TextEditingController _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<OrderCubit, OrderState>(
      listener: (context, state) {
        if (state is OrderCancelled) {
          // Success - close bottom sheet
          Navigator.pop(context, true);
        } else if (state is OrderCancelError) {
          // Error - show snackbar but keep sheet open for retry
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.cancel_outlined,
                            color: Colors.red.shade700,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.cancelOrder,
                                style: AppTextStyles.bold18.copyWith(
                                  color: Colors.red.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isUnavailable
                                    ? l10n.productUnAvailable
                                    : l10n.otherReason,
                                style: AppTextStyles.regular14.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Warning message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.cancelOrderWarning,
                              style: AppTextStyles.regular14.copyWith(
                                color: Colors.orange.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Note field
                    if (!widget.isUnavailable)
                      AppTextFormField(
                        label: l10n.reason,
                        controller: _noteController,
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.pleaseEnterReason;
                          }
                          if (value.trim().length < 10) {
                            return l10n.tooShort;
                          }
                          return null;
                        },
                      ),

                    const SizedBox(height: 24),

                    // Buttons
                    BlocBuilder<OrderCubit, OrderState>(
                      builder: (context, state) {
                        final isLoading = state is CancelingOrder;

                        return Row(
                          children: [
                            Expanded(
                              child: AppCustomButton(
                                onPressed: () => Navigator.pop(context),
                                text: l10n.back,
                                isSecondary: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppCustomButton(
                                onPressed: _handleCancel,
                                text: l10n.confirm,
                                isDelete: true,
                                isLoading: isLoading,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleCancel() {
    if (_formKey.currentState!.validate()) {
      final cubit = context.read<OrderCubit>();
      final note = _noteController.text.trim();

      if (widget.isUnavailable) {
        cubit.cancelOrderUnavailable(orderId: widget.orderId);
      } else {
        cubit.cancelOrderOther(orderId: widget.orderId, note: note);
      }
    }
  }
}

/// Reusable bottom sheet for reporting high price
class ReportHighPriceBottomSheet extends StatefulWidget {
  final String budgetAmount;
  final int orderId;

  const ReportHighPriceBottomSheet({
    super.key,
    required this.budgetAmount,
    required this.orderId,
  });

  @override
  State<ReportHighPriceBottomSheet> createState() =>
      _ReportHighPriceBottomSheetState();
}

class _ReportHighPriceBottomSheetState
    extends State<ReportHighPriceBottomSheet> {
  final TextEditingController _actualPriceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _actualPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<OrderCubit, OrderState>(
      listener: (context, state) {
        if (state is HighPriceReported) {
          // Success - close bottom sheet
          Navigator.pop(context, true);
        } else if (state is HighPriceReportError) {
          // Error - show snackbar but keep sheet open for retry
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.payments_rounded,
                            color: Colors.orange.shade700,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.budgetNotEnough,
                                style: AppTextStyles.bold18.copyWith(
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.actualPriceIsHigher,
                                style: AppTextStyles.regular14.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Budget info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.kSecondaryColor.withOpacity(0.1),
                            AppColors.kSecondaryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.kSecondaryColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet,
                              color: AppColors.kSecondaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.customerBudget,
                                  style: AppTextStyles.regular14.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.budgetAmount} ${l10n.egp}',
                                  style: AppTextStyles.bold18.copyWith(
                                    color: AppColors.kSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Actual price field
                    AppTextFormField(
                      label: l10n.actualProductPrice,
                      controller: _actualPriceController,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.payments_rounded),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterActualPrice;
                        }
                        final price = double.tryParse(value.trim());
                        if (price == null || price <= 0) {
                          return l10n.pleaseEnterValidPrice;
                        }
                        final budget = double.tryParse(widget.budgetAmount);
                        if (budget != null && price <= budget) {
                          return l10n.actualPriceMustBeHigher;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    BlocBuilder<OrderCubit, OrderState>(
                      builder: (context, state) {
                        final isLoading = state is ReportingHighPrice;

                        return Row(
                          children: [
                            Expanded(
                              child: AppCustomButton(
                                onPressed: () => Navigator.pop(context),
                                text: l10n.cancel,
                                isSecondary: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppCustomButton(
                                onPressed: _handleReport,
                                text: l10n.askCustomer,
                                isLoading: isLoading,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleReport() {
    if (_formKey.currentState!.validate()) {
      final actualPrice = double.parse(_actualPriceController.text.trim());
      context.read<OrderCubit>().reportHighPrice(
        orderId: widget.orderId,
        actualPrice: actualPrice,
      );
    }
  }
}

/// Helper function to show cancel order bottom sheet
/// Returns true if order was cancelled successfully
Future<bool?> showCancelOrderSheet({
  required BuildContext context,
  required bool isUnavailable,
  required int orderId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    // Prevent dismissing while loading
    enableDrag: false,
    // Prevent dragging while loading
    builder: (context) =>
        OrderCancelBottomSheet(isUnavailable: isUnavailable, orderId: orderId),
  );
}

/// Helper function to show report high price bottom sheet
/// Returns true if price was reported successfully
Future<bool?> showReportHighPriceSheet({
  required BuildContext context,
  required String budgetAmount,
  required int orderId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    // Prevent dismissing while loading
    enableDrag: false,
    // Prevent dragging while loading
    builder: (context) => ReportHighPriceBottomSheet(
      budgetAmount: budgetAmount,
      orderId: orderId,
    ),
  );
}
