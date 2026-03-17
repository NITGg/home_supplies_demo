import 'package:flutter/material.dart';
import '../../../../../core/widgets/image_with_fallback.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../data/models/wallet_model.dart';
import 'all_badges_dialog.dart';

class WalletBadgeProgressSection extends StatelessWidget {
  final UserBadge currentBadge;
  final UserBadge? nextBadge;
  final int completedCount;
  final int remainingToNext;

  const WalletBadgeProgressSection({
    super.key,
    required this.currentBadge,
    this.nextBadge,
    required this.completedCount,
    required this.remainingToNext,
  });

  void _showAllBadgesDialog(BuildContext context, bool isArabic) {
    showDialog(
      context: context,
      builder: (context) => AllBadgesDialog(
        currentBadge: currentBadge,
        nextBadge: nextBadge,
        completedCount: completedCount,
        isArabic: isArabic,
      ),
    );
  }

  double get progressPercentage {
    if (currentBadge.maxCount == 0) return 0.0;
    return (completedCount / currentBadge.maxCount).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Use Arabic name if available and locale is Arabic
    final badgeName = isArabic && currentBadge.nameAr.isNotEmpty
        ? currentBadge.nameAr
        : currentBadge.name;

    final badgeDescription = isArabic && currentBadge.descriptionAr.isNotEmpty
        ? currentBadge.descriptionAr
        : currentBadge.description;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: GestureDetector(
        onTap: () => _showAllBadgesDialog(context, isArabic),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2D3436), Color(0xFF636E72)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations.badgeProgress,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tap indicator
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_right,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Progress bar with badge icon
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Background bar
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // Progress bar
                  FractionallySizedBox(
                    widthFactor: progressPercentage,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFDCB6E), Color(0xFFFFD700)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFDCB6E).withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$completedCount / ${currentBadge.maxCount} ${localizations.orders}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${(progressPercentage * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFFDCB6E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Badge info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ImageWithIconFallback(
                      imageUrl: currentBadge.image,
                      height: 70,
                      width: 70,
                      fit: BoxFit.scaleDown,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badgeDescription,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${localizations.earn} ${currentBadge.commissionRate.toStringAsFixed(0)}% ${localizations.discount}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF00B894),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (nextBadge != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            isArabic
                                ? '$remainingToNext طلب للوصول إلى ${nextBadge!.nameAr.isNotEmpty ? nextBadge!.nameAr : nextBadge!.name}'
                                : '$remainingToNext more to reach ${nextBadge!.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Tap hint
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app,
                        color: Color(0xFFFDCB6E),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isArabic
                            ? 'اضغط لعرض جميع الشارات'
                            : 'Tap to view all badges',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}