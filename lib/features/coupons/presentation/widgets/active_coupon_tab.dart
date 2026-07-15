import 'package:flutter/material.dart';
import 'package:tawreedat_courier/core/style/app_colors.dart';
import 'package:tawreedat_courier/l10n/app_localizations.dart';

import '../../data/models/coupns_model.dart';
import 'coupons_shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Active Coupon Tab
//
// Normal state  → dark charcoal gradient  (unchanged)
// Urgent state  → same dark charcoal gradient + subtle amber accents only
//   • progress bar fill → kPrimaryColor (amber)
//   • days-left value   → kPrimaryColor (amber)
//   • "⚠ Expires" badge → kPrimaryColor bg (amber)
//   • Everything else stays the same as normal
// ─────────────────────────────────────────────────────────────────────────────

class ActiveCouponTab extends StatelessWidget {
  final ActiveCouponModel? active;
  final bool isRtl;

  const ActiveCouponTab({super.key, required this.active, required this.isRtl});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (active == null) {
      return CouponEmptyPlaceholder(
        icon: Icons.verified_outlined,
        message: l10n.noActiveCoupon,
        isPositive: true,
      );
    }

    final coupon = active!.coupon;
    final daysLeft = active!.daysRemaining;
    final totalDays = (coupon?.durationDays ?? 30).clamp(1, 9999);
    final progress = (daysLeft / totalDays).clamp(0.0, 1.0);
    final isUrgent = daysLeft < 2;

    // ── Colour tokens ────────────────────────────────────────────────────
    // Same gradient for both states
    const gradientColors = [Color(0xFF2D3436), Color(0xFF636E72)];

    // Text / icon colours — identical for both states
    const contentColor = Colors.white;
    const subtleColor = Colors.white70;

    // Glass-overlay — identical for both states
    final overlayColor = Colors.white.withOpacity(0.15);
    final overlayBorderColor = Colors.white.withOpacity(0.2);

    // Dashed separator — identical for both states
    final dashedLineColor = Colors.white.withOpacity(0.4);

    // Progress bar — amber fill only when urgent
    final progressBg = Colors.white.withOpacity(0.2);
    final progressFill = isUrgent ? AppColors.kPrimaryColor : Colors.white;

    // "ACTIVE" badge — identical for both states
    final badgeBg = Colors.white.withOpacity(0.2);
    final badgeBorderColor = Colors.white.withOpacity(0.5);
    const badgeTextColor = Colors.white;

    // Card drop-shadow — identical for both states
    final shadowColor = AppColors.kSecondaryColor.withOpacity(0.4);

    // Days-left value — amber accent only when urgent
    final daysColor = isUrgent ? AppColors.kPrimaryColor : Colors.white;

    // ── Data ─────────────────────────────────────────────────────────────
    final localTitle = isRtl
        ? (coupon?.titleAr ?? coupon?.title ?? l10n.active)
        : (coupon?.title ?? l10n.active);
    final localDesc = isRtl
        ? (coupon?.descriptionAr ?? coupon?.description)
        : coupon?.description;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main Card ──────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon box
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: overlayColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: overlayBorderColor),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: contentColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localTitle,
                              style: const TextStyle(
                                color: contentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${l10n.createdDate} ${formatCouponDate(active!.startDate)}',
                              style: const TextStyle(
                                color: subtleColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // "ACTIVE" badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: badgeBorderColor, width: 1),
                        ),
                        child: Text(
                          l10n.active.toUpperCase(),
                          style: const TextStyle(
                            color: badgeTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Dashed separator ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: List.generate(
                      40,
                          (i) => Expanded(
                        child: Container(
                          height: 1,
                          color: i.isEven ? dashedLineColor : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Stats row ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _StatChip(
                        icon: Icons.star_rounded,
                        value:
                        '+${active!.snapshotBonusCourierFee.toStringAsFixed(0)}%',
                        label: l10n.commissionRate,
                        contentColor: contentColor,
                        subtleColor: subtleColor,
                        overlayColor: overlayColor,
                        overlayBorderColor: overlayBorderColor,
                      ),
                    ],
                  ),
                ),

                // ── Description ──────────────────────────────────────────
                if (localDesc != null && localDesc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Text(
                      localDesc,
                      style: const TextStyle(
                        color: subtleColor,
                        fontSize: 13,
                      ),
                    ),
                  ),

                // ── Progress section ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.timeRemaining,
                            style: const TextStyle(
                              color: subtleColor,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '$daysLeft ${l10n.days}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: daysColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: progressBg,
                            valueColor: AlwaysStoppedAnimation(progressFill),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${l10n.expires}: ${formatCouponDate(active!.endDate)}',
                            style: const TextStyle(
                              color: subtleColor,
                              fontSize: 12,
                            ),
                          ),
                          // Urgent warning badge — only visual difference
                          if (isUrgent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.kPrimaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '⚠ ${l10n.expires}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color contentColor;
  final Color subtleColor;
  final Color overlayColor;
  final Color overlayBorderColor;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.contentColor,
    required this.subtleColor,
    required this.overlayColor,
    required this.overlayBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: overlayColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: overlayBorderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: subtleColor, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: contentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(color: subtleColor, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated pulsing dot (kept for potential future use)
// ─────────────────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;

  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}