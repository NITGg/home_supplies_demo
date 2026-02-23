import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/style/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../l10n/app_localizations.dart';

class ManualTopUpScreen extends StatelessWidget {
  final int amount;

  const ManualTopUpScreen({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          l10n.manualTransfer,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions Header
            Text(
              l10n.instructions,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _InstructionStep(step: 1, title: l10n.transferAmount),

            const SizedBox(height: 24),

            // Vodafone Cash
            _PaymentDetailCard(
              asset: 'assets/images/vodaCash.png',
              title: l10n.vodafoneCash,
              detail: '01145862133',
              color: const Color(0xFFE60000),
            ),

            const SizedBox(height: 12),

            // InstaPay
            _PaymentDetailCard(
              asset: 'assets/images/instaPay.png',
              title: l10n.instaPay,
              detail: 'tawreedat@instapay.eg',
              color: const Color(0xFF6C5CE7),
            ),

            const SizedBox(height: 32),

            _InstructionStep(step: 2, title: l10n.keepReceipt),

            const SizedBox(height: 24),

            _InstructionStep(step: 3, title: l10n.contactSupport),

            const SizedBox(height: 12),

            // Support Contact Card
            _PaymentDetailCard(
              isWhatsapp: true,
              icon: Icons.support_agent_rounded,
              title: l10n.support,
              detail: '01145862133',
              color: AppColors.kPrimaryColor,
            ),

            const SizedBox(height: 32),

            // Important Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.balanceWillBeAdded,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Done Button
            AppCustomButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                context.pushReplacement('/WalletScreen');
              },
              text: l10n.done,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final int step;
  final String title;

  const _InstructionStep({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.kPrimaryColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentDetailCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final bool? isWhatsapp;
  final String? asset;
  final String detail;
  final Color color;

  const _PaymentDetailCard({
    this.icon,
    this.asset,
    this.isWhatsapp,
    required this.title,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: icon != null
                ? Icon(icon, color: color, size: 24)
                : Image.asset(asset!, fit: BoxFit.cover, width: 40, height: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (isWhatsapp == true)
            IconButton(
              onPressed: () {
                launchUrl(
                  Uri.parse("https://wa.me/+2$detail?text=عملية شحن جديدة"),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: SvgPicture.asset(
                'assets/images/whatsapp-icon.svg',
                fit: BoxFit.scaleDown,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: detail));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.copiedToClipboard),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(Icons.copy, color: color),
          ),
        ],
      ),
    );
  }
}
