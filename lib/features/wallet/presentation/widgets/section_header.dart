import 'package:flutter/material.dart';

import '../../../../../core/style/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;

  const SectionHeader({
    super.key,
    required this.title,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: onViewAll,
            child: Row(
              children: [
                Text(
                  l10n.viewAll,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.kSecondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.kSecondaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
