// ── _ProfileAvatar ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:tawreedat_courier/core/widgets/image_with_fallback.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../stats/data/models/stats_models.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final BadgeProgressData? badgeProgress;

  const ProfileAvatar({super.key, this.imageUrl, this.badgeProgress});

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context)!.localeName == 'ar';
    final badgeName = badgeProgress == null
        ? null
        : isArabic
        ? (badgeProgress!.currentBadge.nameAr.isNotEmpty
        ? badgeProgress!.currentBadge.nameAr
        : badgeProgress!.currentBadge.name)
        : badgeProgress!.currentBadge.name;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Hero(
            tag: 'profile_avatar',
            child: ClipOval(
              child: imageUrl != null
                  ? ImageWithIconFallback(
                imageUrl: imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                isCircle: true,
              )
                  : SvgPicture.asset(
                'assets/images/drawer/profile_placholder.svg',
              ),
            ),
          ),
        ),
        if (badgeName != null && badgeName.isNotEmpty)
          Positioned(
            bottom: -20,
            right: 10,
            left: 10,
            child: Text(
              badgeName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}