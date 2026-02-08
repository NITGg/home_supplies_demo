import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';

import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../data/models/orders_model.dart';

class QrCodeScreen extends StatelessWidget {
  final QrCodeModel qrCodeModel;

  const QrCodeScreen({super.key, required this.qrCodeModel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.kSecondaryColor),
          onPressed: () => context.pop(context),
        ),
        title: Text(
          'Delivery QR Code',
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
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green.shade600,
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Delivery Ready!',
                        style: AppTextStyles.bold25.copyWith(
                          color: AppColors.kSecondaryColor,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Show this QR code to the customer for confirmation',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey.shade600,
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
                              color: AppColors.kPrimaryColor.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // QR Code Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                base64Decode(qrCodeModel.qrCode.split(',')[1]),
                                width: 250,
                                height: 250,
                                fit: BoxFit.contain,
                              ),
                            ),

                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.kSecondaryLightColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Order #${qrCodeModel.orderId}',
                                style: AppTextStyles.bold14.copyWith(
                                  color: AppColors.kSecondaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Instructions',
                                    style: AppTextStyles.bold14.copyWith(
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '1. Ask the customer to open their app\n'
                                    '2. They will scan this QR code\n'
                                    '3. Wait for confirmation\n'
                                    '4. Delivery complete!',
                                    style: AppTextStyles.regular14.copyWith(
                                      fontSize: 13,
                                      color: Colors.blue.shade800,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
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
                onPressed: () => context.pop(context),
                text: 'Done',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
