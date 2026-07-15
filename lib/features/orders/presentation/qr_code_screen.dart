import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/core/widgets/banners.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/review_bottom_sheet.dart';
import 'dart:async';
import 'dart:convert';

import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/utils/socket_service.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/success_mark.dart';
import '../../../core/widgets/text_form.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/orders_model.dart';
import '../manager/orders_cubit.dart';
import '../manager/orders_states.dart';

class QrCodeScreen extends StatefulWidget {
  final QrCodeModel qrCodeModel;
  final int orderId;
  final double actualPrice;
  final int courierId;
  final int customerId;

  const QrCodeScreen({
    super.key,
    required this.qrCodeModel,
    required this.orderId,
    required this.actualPrice,
    required this.courierId,
    required this.customerId,
  });

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  StreamSubscription<Map<String, dynamic>>? _deliveryConfirmedSub;
  bool _reviewShown = false;

  @override
  void initState() {
    super.initState();
    _deliveryConfirmedSub = SocketService().onDeliveryConfirmedByCustomer
        .listen(_onDeliveryConfirmedByCustomer);
  }

  @override
  void dispose() {
    _deliveryConfirmedSub?.cancel();
    super.dispose();
  }

  void _onDeliveryConfirmedByCustomer(Map<String, dynamic> data) {
    // Guard: only react if the event belongs to this order (when orderId is
    // present in the payload), and only show the sheet once.
    final payloadOrderId = data['orderId'] as int?;
    if (payloadOrderId != null && payloadOrderId != widget.orderId) return;
    if (_reviewShown) return;
    if (!mounted) return;
    _reviewShown = true;
    _showReviewSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<OrderCubit, OrderState>(
      listener: (context, state) {
        if (state is ConfirmWithOtpError) {
          showErrorBanner(context, state.message);
        }
        if (state is FinalConfirmSuccess && !_reviewShown) {
          _reviewShown = true;
          Navigator.pop(context); // close OTP sheet
          // Defer one frame — the OTP sheet's dismiss animation must fully
          // complete before a new modal route can be pushed reliably.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showReviewSheet(context);
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.kBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.kSecondaryColor),
            onPressed: () => context.go('/mainHome'),
          ),
          title: Text(
            l10n.deliveryQrCode,
            style: AppTextStyles.bold18.copyWith(
              color: AppColors.kSecondaryColor,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Success Icon
                        SuccessMark(),

                        const SizedBox(height: 24),

                        Text(
                          l10n.deliveryReady,
                          style: AppTextStyles.bold25.copyWith(
                            color: AppColors.kSecondaryColor,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          l10n.showQrCodeMessage,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.regular14.copyWith(
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // QR Code Container
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.kPrimaryColor.withOpacity(
                                  0.15,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // QR Code Image with decoration
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.kSecondaryLightColor,
                                      AppColors.kSecondaryLightColor
                                          .withOpacity(0.5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.all(16),
                                    child: Image.memory(
                                      base64Decode(
                                        widget.qrCodeModel.qrCode.split(',')[1],
                                      ),
                                      width: 250,
                                      height: 250,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.kPrimaryColor,
                                      AppColors.kPrimaryColor.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.kPrimaryColor
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.receipt_long,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${l10n.order} #${widget.qrCodeModel.orderId}',
                                      style: AppTextStyles.bold14.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Instructions
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.info_outline,
                                      color: Colors.blue.shade700,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    l10n.instructions,
                                    style: AppTextStyles.bold16.copyWith(
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildInstructionStep(
                                context,
                                l10n.instructionStep1,
                                Icons.phone_android,
                              ),
                              _buildInstructionStep(
                                context,
                                l10n.instructionStep2,
                                Icons.qr_code_scanner,
                              ),
                              _buildInstructionStep(
                                context,
                                l10n.instructionStep3,
                                Icons.schedule,
                              ),
                              _buildInstructionStep(
                                context,
                                l10n.instructionStep4,
                                Icons.check_circle,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Button — manual OTP entry only (Done button removed;
              // the review sheet opens automatically when the customer confirms
              // via the order:delivery_confirmed_customer socket event).
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: AppCustomButton(
                  isSecondary: true,
                  onPressed: () => _showManualConfirmation(context),
                  text: l10n.enterCodeManually,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewSheet(BuildContext context) {
    // Capture the router before crossing the async boundary so it stays
    // valid even if the widget rebuilds while the sheet is open.
    final router = GoRouter.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewBottomSheet(
        orderId: widget.orderId,
        customerId: widget.customerId,
      ),
    ).then((_) {
      if (router.canPop()) {
        router.pop();
      }
    });
  }

  Widget _buildInstructionStep(
    BuildContext context,
    String text,
    IconData icon, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.regular14.copyWith(
                color: Colors.blue.shade800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualConfirmation(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final otpController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  /// ✅ FORM
                  Form(
                    key: formKey,
                    child: AppTextFormField(
                      keyboardType: TextInputType.number,
                      label: l10n.confirmCode,
                      controller: otpController,
                      prefixIcon: const Icon(Icons.qr_code),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.enterCodeManually;
                        }
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// ✅ BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: BlocBuilder<OrderCubit, OrderState>(
                      builder: (context, state) {
                        return AppCustomButton(
                          isLoading: state is ConfirmingWithOtp,
                          enabled: otpController.text.trim().isNotEmpty,
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;

                            context
                                .read<OrderCubit>()
                                .confirmWithOtpAndComplete(
                                  orderId: widget.orderId,
                                  actualPrice: widget.actualPrice,
                                  otp: otpController.text.trim(),
                                  courierId: widget.courierId,
                                );
                          },
                          text: l10n.confirm,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
