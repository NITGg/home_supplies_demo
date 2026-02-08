import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';

import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/orders_model.dart';

class QrCodeScreen extends StatelessWidget {
  final QrCodeModel qrCodeModel;

  const QrCodeScreen({super.key, required this.qrCodeModel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.kSecondaryColor),
          onPressed: () => context.pop(),
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
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade50,
                              Colors.green.shade100,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 64,
                          color: Colors.green.shade600,
                        ),
                      ),

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
                              color: AppColors.kPrimaryColor.withOpacity(0.15),
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
                                    AppColors.kSecondaryLightColor.withOpacity(0.5),
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
                                    base64Decode(qrCodeModel.qrCode.split(',')[1]),
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
                                    color: AppColors.kPrimaryColor.withOpacity(0.3),
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
                                    '${l10n.orders} #${qrCodeModel.orderId}',
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

            // Bottom Button
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
                onPressed: () => context.pop(),
                text: l10n.done,
              ),
            ),
          ],
        ),
      ),
    );
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
            child: Icon(
              icon,
              size: 16,
              color: Colors.blue.shade700,
            ),
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
}