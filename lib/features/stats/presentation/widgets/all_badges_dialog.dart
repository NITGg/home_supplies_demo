import 'package:flutter/material.dart';
import '../../../../core/widgets/image_with_fallback.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/models/user_profile_model.dart';

class AllBadgesDialog extends StatefulWidget {
  final BadgeProgressData badgeProgress;
  final bool isArabic;

  const AllBadgesDialog({
    super.key,
    required this.badgeProgress,
    required this.isArabic,
  });

  @override
  State<AllBadgesDialog> createState() =>
      _AllBadgesDialogState();
}

class _AllBadgesDialogState extends State<AllBadgesDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              color: Colors.white,
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
                      colors: [Color(0xFF2D3436), Color(0xFF636E72)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.stars,
                        color: Color(0xFFFDCB6E),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isArabic ? 'جميع الشارات' : 'All Badges',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.isArabic
                                  ? '${widget.badgeProgress.allBadges.length} شارات متاحة'
                                  : '${widget.badgeProgress.allBadges.length} badges available',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Badges List
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    shrinkWrap: true,
                    itemCount: widget.badgeProgress.allBadges.length,
                    itemBuilder: (context, index) {
                      final badge = widget.badgeProgress.allBadges[index];
                      final isCurrentBadge =
                          badge.id == widget.badgeProgress.currentBadge.id;

                      return AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          final delay = index * 0.1;
                          final animationValue = Curves.easeOut.transform(
                            ((_animationController.value - delay).clamp(0.0, 1.0)),
                          );

                          return Opacity(
                            opacity: animationValue,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - animationValue)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildBadgeCard(
                          context,
                          badge,
                          isCurrentBadge,
                          localizations,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCard(
      BuildContext context,
      BadgeModel badge,
      bool isCurrentBadge,
      AppLocalizations localizations,
      ) {
    final badgeName = widget.isArabic && badge.nameAr.isNotEmpty
        ? badge.nameAr
        : badge.name;
    final badgeDescription =
    widget.isArabic && badge.descriptionAr.isNotEmpty
        ? badge.descriptionAr
        : badge.description;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentBadge
            ? const Color(0xFFFDCB6E).withOpacity(0.1)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentBadge
              ? const Color(0xFFFDCB6E)
              : Colors.grey.withOpacity(0.2),
          width: isCurrentBadge ? 2 : 1,
        ),
        boxShadow: isCurrentBadge
            ? [
          BoxShadow(
            color: const Color(0xFFFDCB6E).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Stack(
        children: [
          // Current badge indicator
          if (isCurrentBadge)
            Positioned(
              top: 8,
              right: widget.isArabic ? null : 8,
              left: widget.isArabic ? 8 : null,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDCB6E), Color(0xFFFFD700)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFDCB6E).withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.isArabic ? 'الشارة الحالية' : 'Current Badge',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Badge Image
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                      if (isCurrentBadge) const SizedBox(height: 24),
                      Text(
                        badgeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCurrentBadge
                              ? const Color(0xFF2D3436)
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badgeDescription,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Requirements and Commission in a nice layout
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Requirements
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.local_shipping,
                                    size: 16,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${badge.minCount} - ${badge.maxCount} ${localizations.deliveries}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Divider(height: 1),
                            const SizedBox(height: 6),

                            // Commission Rate
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.trending_up,
                                    size: 16,
                                    color: Colors.green[700],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${100 - badge.ratio}% ${localizations.commissionRate}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
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
        ],
      ),
    );
  }
}