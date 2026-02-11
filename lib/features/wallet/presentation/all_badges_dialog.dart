import 'package:flutter/material.dart';
import '../../../../core/widgets/image_with_fallback.dart';
import '../../../../l10n/app_localizations.dart';
import '../data/models/wallet_model.dart';

class AllBadgesDialog extends StatelessWidget {
  final UserBadge currentBadge;
  final UserBadge? nextBadge;
  final int completedCount;
  final bool isArabic;

  const AllBadgesDialog({
    super.key,
    required this.currentBadge,
    this.nextBadge,
    required this.completedCount,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF2D3436),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF636E72), Color(0xFF2D3436)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'جميع الشارات' : 'All Badges',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Current Badge
                  _BadgeCard(
                    badge: currentBadge,
                    isArabic: isArabic,
                    isCurrent: true,
                    completedCount: completedCount,
                    localizations: localizations,
                  ),

                  if (nextBadge != null) ...[
                    const SizedBox(height: 20),
                    // Arrow indicator
                    Icon(
                      Icons.arrow_downward,
                      color: Colors.white.withOpacity(0.5),
                      size: 30,
                    ),
                    const SizedBox(height: 20),
                    // Next Badge
                    _BadgeCard(
                      badge: nextBadge!,
                      isArabic: isArabic,
                      isCurrent: false,
                      completedCount: completedCount,
                      localizations: localizations,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final UserBadge badge;
  final bool isArabic;
  final bool isCurrent;
  final int completedCount;
  final AppLocalizations localizations;

  const _BadgeCard({
    required this.badge,
    required this.isArabic,
    required this.isCurrent,
    required this.completedCount,
    required this.localizations,
  });

  @override
  Widget build(BuildContext context) {
    final badgeName =
    isArabic && badge.nameAr.isNotEmpty ? badge.nameAr : badge.name;
    final badgeDescription = isArabic && badge.descriptionAr.isNotEmpty
        ? badge.descriptionAr
        : badge.description;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent
            ? Colors.white.withOpacity(0.15)
            : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: const Color(0xFFFDCB6E), width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Badge Image
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ImageWithIconFallback(
              imageUrl: badge.image,
              height: 60,
              width: 60,
              fit: BoxFit.scaleDown,
            ),
          ),
          const SizedBox(width: 16),

          // Badge Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        badgeName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDCB6E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isArabic ? 'الحالية' : 'Current',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  badgeDescription,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${badge.minCount} - ${badge.maxCount} ${localizations.deliveries}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${localizations.earn} ${badge.commissionRate.toStringAsFixed(0)}% ${localizations.commissionRate}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF00B894),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}