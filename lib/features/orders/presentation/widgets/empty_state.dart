import 'package:flutter/material.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../orders_list_screen.dart';

class OrderEmptyState extends StatelessWidget {
  final ViewMode viewMode;

  const OrderEmptyState({
    super.key,
    required this.viewMode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isActive = viewMode == ViewMode.active;

    return AppEmptyState(
      icon: isActive ? Icons.shopping_bag_outlined : Icons.history_outlined,
      title: isActive ? l10n.noActiveOrder : l10n.noData,
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Future<void> Function()? onRefresh;
  final bool useScroll;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onRefresh,
    this.useScroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.kSecondaryLightColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 80,
              color: AppColors.kPrimaryColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: AppTextStyles.bold18.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTextStyles.regular14.copyWith(
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (onRefresh != null) ...[
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.kPrimaryColor,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );

    if (useScroll && onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppColors.kPrimaryColor,
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(child: content),
          ],
        ),
      );
    }

    return content;
  }
}