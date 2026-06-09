import 'package:flutter/material.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';
import 'package:tawreedat_go/core/style/text_styles.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';

import '../../../core/widgets/image_with_fallback.dart';
import '../data/models/supplier_models.dart';

/// A horizontal scrollable card representing a supplier.
/// Tapping it navigates to the supplier's detail screen.
class SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback? onTap;
  final bool isSelected;

  const SupplierCard({
    super.key,
    required this.supplier,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = supplier.photoUrl;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 88,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Avatar ────────────────────────────────────────────────────
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.grey.shade200,
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _SupplierAvatar(
                photoUrl: photoUrl,
                name: supplier.displayName,
              ),
            ),

            const SizedBox(height: 6),

            // ── Name ──────────────────────────────────────────────────────
            Text(
              supplier.displayName,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? theme.colorScheme.primary : Colors.black87,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // ── DIST ──────────────────────────────────────────────────────
            Text(
              supplier.distanceKm < 10
                  ? '${AppLocalizations.of(context)!.far} ${supplier.distanceKm.floor()} ${AppLocalizations.of(context)!.km}'
                  : "${AppLocalizations.of(context)!.far} 10+ ${AppLocalizations.of(context)!.km}",
              style: AppTextStyles.regular14.copyWith(fontSize: 10,color: AppColors.kPrimaryColor),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;

  const _SupplierAvatar({this.photoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ImageWithIconFallback(imageUrl: photoUrl!, fit: BoxFit.cover);
    }
    return _placeholder(theme);
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primaryContainer,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
