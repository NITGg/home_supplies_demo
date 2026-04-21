import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';

class CategoriesFallbackWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final String lottieAsset;

  const CategoriesFallbackWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.lottieAsset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🎬 Lottie
          SizedBox(height: 160, child: Lottie.asset(lottieAsset, repeat: true)),

          const SizedBox(height: 12),

          // 📝 Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          // 🧾 Subtitle
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
