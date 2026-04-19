import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';

import '../../../../l10n/app_localizations.dart';
import '../data/models/coupons_model.dart';
import '../manager/coupons_cubit.dart';
import '../manager/coupons_states.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

class CouponTickerTitle extends StatefulWidget {
  const CouponTickerTitle({super.key});

  @override
  State<CouponTickerTitle> createState() => _CouponTickerTitleState();
}

class _CouponTickerTitleState extends State<CouponTickerTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CouponCubit, CouponState>(
      builder: (context, state) {
        if (state is CouponsLoaded && state.activeCoupons.isNotEmpty) {
          if (!_hasAnimated) {
            _hasAnimated = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _fadeController.forward(),
            );
          }
          return FadeTransition(
            opacity: _fadeAnimation,
            child: _CouponPill(
              coupon: state.activeCoupons.first,
              allCoupons: state.activeCoupons,
              onViewAll: () => _showCouponsDialog(context),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _showCouponsDialog(BuildContext context) {
    final isAr = AppLocalizations.of(context)?.localeName == 'ar';
    final cubit = context.read<CouponCubit>();
    cubit.loadCoupons();

    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: CouponsDialog(isAr: isAr ?? false),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact pill
// ─────────────────────────────────────────────────────────────────────────────

class _CouponPill extends StatefulWidget {
  final Coupon coupon;
  final List<Coupon> allCoupons;
  final VoidCallback onViewAll;

  const _CouponPill({
    required this.coupon,
    required this.allCoupons,
    required this.onViewAll,
  });

  @override
  State<_CouponPill> createState() => _CouponPillState();
}

class _CouponPillState extends State<_CouponPill>
    with TickerProviderStateMixin {
  // 'idle' → 'copied' → 'viewMore' → 'idle'
  _PillPhase _phase = _PillPhase.idle;
  bool _showHint = false;

  // Tap-press controller (shrink on tap)
  late final AnimationController _tapController;
  late final Animation<double> _tapScale;

  // Hint nudge controller (gentle bounce + brief hint label)
  late final AnimationController _hintController;
  late final Animation<double> _hintScale;

  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _tapScale = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeInOut));

    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // Bouncy scale: grows slightly then snaps back with elasticity
    _hintScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.06,
          end: 0.97,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.97,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_hintController);

    // Show hint every 4 s, only when pill is idle
    _hintTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || _phase != _PillPhase.idle) return;

      setState(() => _showHint = true);
      _hintController.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted && _phase == _PillPhase.idle) {
        setState(() => _showHint = false);
      }
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _tapController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_phase == _PillPhase.viewMore) {
      widget.onViewAll();
      setState(() => _phase = _PillPhase.idle);
      return;
    }

    if (_phase != _PillPhase.idle) return;

    // Cancel any active hint so it doesn't overlap
    _hintTimer?.cancel();
    setState(() => _showHint = false);

    // Press animation
    await _tapController.forward();
    await _tapController.reverse();

    await Clipboard.setData(ClipboardData(text: widget.coupon.code));

    setState(() => _phase = _PillPhase.copied);

    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    if (widget.allCoupons.length > 1) {
      setState(() => _phase = _PillPhase.viewMore);
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted) setState(() => _phase = _PillPhase.idle);
    } else {
      setState(() => _phase = _PillPhase.idle);
    }

    // Re-arm the hint timer after the tap flow finishes
    _hintTimer?.cancel();
    _hintTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || _phase != _PillPhase.idle) return;

      setState(() => _showHint = true);
      _hintController.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted && _phase == _PillPhase.idle) {
        setState(() => _showHint = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context)?.localeName == 'ar';
    final label = _labelFor(widget.coupon, isAr ?? false);

    // Combine tap-press scale and hint-bounce scale
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _tapScale,
        child: ScaleTransition(
          scale: _hintScale,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.kPrimaryColor.withOpacity(0.15),
                  Colors.orange.shade50,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.kPrimaryColor.withOpacity(0.4),
                width: 1.2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: _pillContent(label, isAr ?? false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillContent(String label, bool isAr) {
    switch (_phase) {
      case _PillPhase.idle:
        return _IdlePillContent(
          key: const ValueKey('idle'),
          coupon: widget.coupon,
          label: label,
          isAr: isAr,
          onViewAll: widget.onViewAll,
          // ← pass it down
          showHint: _showHint, // ← pass hint flag down
        );

      case _PillPhase.copied:
        return _StatusPillContent(
          key: const ValueKey('copied'),
          icon: Icons.check_circle_outline_rounded,
          iconColor: Colors.green.shade600,
          text: isAr ? 'تم نسخ الكود!' : 'Code copied!',
          textColor: Colors.green.shade700,
        );

      case _PillPhase.viewMore:
        return _StatusPillContent(
          key: const ValueKey('viewMore'),
          icon: Icons.card_giftcard,
          iconColor: Colors.orange.shade700,
          text: isAr
              ? 'عرض كل الكوبونات (${widget.allCoupons.length})'
              : 'View all coupons (${widget.allCoupons.length})',
          textColor: Colors.orange.shade800,
          trailingIcon: Icons.chevron_right_rounded,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Idle content
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Idle content  (updated)
// ─────────────────────────────────────────────────────────────────────────────

class _IdlePillContent extends StatelessWidget {
  final Coupon coupon;
  final String label;
  final bool isAr;
  final VoidCallback onViewAll;
  final bool showHint; // ← new

  const _IdlePillContent({
    super.key,
    required this.coupon,
    required this.label,
    required this.isAr,
    required this.onViewAll,
    this.showHint = false, // ← new
  });

  @override
  Widget build(BuildContext context) {
    final hintText = isAr ? 'اضغط لنسخ الكود' : 'Tap to copy';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Label / hint (swaps in place) ─────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: showHint
                  ? Row(
                      key: const ValueKey('hint'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 13,
                          color: AppColors.kPrimaryColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            hintText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: isAr
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      key: const ValueKey('label'),
                      label,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade900,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: isAr
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                    ),
            ),
          ),
        ),

        // ── Divider ───────────────────────────────────────────────────────
        Container(
          width: 1,
          height: 22,
          color: AppColors.kPrimaryColor.withOpacity(0.3),
          margin: const EdgeInsets.symmetric(horizontal: 6),
        ),

        // ── "All" button — always visible ─────────────────────────────────
        GestureDetector(
          onTap: onViewAll,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.card_giftcard,
                  size: 13,
                  color: AppColors.kPrimaryColor,
                ),
                const SizedBox(width: 3),
                Text(
                  isAr ? 'الكل' : 'All',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.kPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
} // ─────────────────────────────────────────────────────────────────────────────
// Status content (copied / view more / hint)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPillContent extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textColor;
  final IconData? trailingIcon;

  const _StatusPillContent({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 2),
            Icon(trailingIcon, size: 15, color: iconColor),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase enum
// ─────────────────────────────────────────────────────────────────────────────

enum _PillPhase { idle, copied, viewMore }

// ─────────────────────────────────────────────────────────────────────────────
// Label builder
// ─────────────────────────────────────────────────────────────────────────────

String _labelFor(Coupon coupon, bool isAr) {
  String base = '';

  if (isAr) {
    if (coupon.isWalletCredit) {
      final parts = <String>[];
      if (coupon.walletAmountCents > 0)
        parts.add('${coupon.walletAmount.toStringAsFixed(0)} جنيه');
      if (coupon.walletPoints > 0) parts.add('${coupon.walletPoints} نقطة');
      base = parts.join(' + ');
    } else if (coupon.discountValue != null) {
      if (coupon.isPercentDiscount) {
        base = coupon.isDeliveryFeeDiscount
            ? 'خصم ${coupon.discountValue!.toStringAsFixed(0)}٪ على التوصيل'
            : 'خصم ${coupon.discountValue!.toStringAsFixed(0)}٪ على طلبك';
      } else {
        base = coupon.isDeliveryFeeDiscount
            ? 'خصم ${coupon.discountValue!.toStringAsFixed(0)} جنيه على التوصيل'
            : 'خصم ${coupon.discountValue!.toStringAsFixed(0)} جنيه على طلبك';
      }
    }
    if (base.isNotEmpty && coupon.minOrdersCount > 0)
      base += ' · ${coupon.minOrdersCount}+ طلب';
  } else {
    if (coupon.isWalletCredit) {
      final parts = <String>[];
      if (coupon.walletAmountCents > 0)
        parts.add('${coupon.walletAmount.toStringAsFixed(0)} EGP credit');
      if (coupon.walletPoints > 0) parts.add('${coupon.walletPoints} pts');
      base = parts.join(' + ');
    } else if (coupon.discountValue != null) {
      if (coupon.isPercentDiscount) {
        base = coupon.isDeliveryFeeDiscount
            ? '${coupon.discountValue!.toStringAsFixed(0)}% off delivery'
            : '${coupon.discountValue!.toStringAsFixed(0)}% off your order';
      } else {
        base = coupon.isDeliveryFeeDiscount
            ? '${coupon.discountValue!.toStringAsFixed(0)} EGP off delivery'
            : '${coupon.discountValue!.toStringAsFixed(0)} EGP off your order';
      }
    }
    if (base.isNotEmpty && coupon.minOrdersCount > 0)
      base += ' · ${coupon.minOrdersCount}+ orders';
  }

  return base;
}
// ─────────────────────────────────────────────────────────────────────────────
// CouponsDialog
// ─────────────────────────────────────────────────────────────────────────────

class CouponsDialog extends StatelessWidget {
  final bool isAr;

  const CouponsDialog({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: BlocBuilder<CouponCubit, CouponState>(
          builder: (context, state) {
            if (state is CouponLoading) {
              return const SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              );
            }
            if (state is CouponsLoaded) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  const SizedBox(height: 16),
                  _list(context, state.activeCoupons),
                ],
              );
            }
            return const SizedBox(
              height: 120,
              child: Center(child: Text('Failed to load')),
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isAr ? 'الكوبونات المتاحة' : 'Available Coupons',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, List<Coupon> coupons) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: coupons.length,
        separatorBuilder: (_, __) => const Divider(height: 24),
        itemBuilder: (_, i) => _CouponCard(coupon: coupons[i], isAr: isAr),
      ),
    );
  }
}

class _CouponCard extends StatefulWidget {
  final Coupon coupon;
  final bool isAr;

  const _CouponCard({required this.coupon, required this.isAr});

  @override
  State<_CouponCard> createState() => _CouponCardState();
}

class _CouponCardState extends State<_CouponCard> {
  bool _copied = false;

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.coupon.code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  String get _discountDescription {
    final c = widget.coupon;
    if (c.isWalletCredit) {
      final parts = <String>[];
      if (c.walletAmountCents > 0) {
        parts.add(
          widget.isAr
              ? '${c.walletAmount.toStringAsFixed(0)} جنيه رصيد محفظة'
              : '${c.walletAmount.toStringAsFixed(0)} EGP wallet credit',
        );
      }
      if (c.walletPoints > 0) {
        parts.add(
          widget.isAr ? '${c.walletPoints} نقطة' : '${c.walletPoints} points',
        );
      }
      return parts.join(' + ');
    } else if (c.discountValue != null) {
      final target = c.isDeliveryFeeDiscount
          ? (widget.isAr ? 'على رسوم التوصيل' : 'off delivery fee')
          : (widget.isAr ? 'على طلبك' : 'off your order');
      if (c.isPercentDiscount) {
        return widget.isAr
            ? 'خصم ${c.discountValue!.toStringAsFixed(0)}٪ $target'
            : '${c.discountValue!.toStringAsFixed(0)}% $target';
      } else {
        return widget.isAr
            ? 'خصم ${c.discountValue!.toStringAsFixed(0)} جنيه $target'
            : '${c.discountValue!.toStringAsFixed(0)} EGP $target';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _discountDescription,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          // After the discount description Text widget:
          if (widget.coupon.minOrdersCount > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 13,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.isAr
                      ? 'يتطلب ${widget.coupon.minOrdersCount} طلب${widget.coupon.minOrdersCount > 1 ? 'ات' : ''} مكتمل${widget.coupon.minOrdersCount > 1 ? 'ة' : ''}'
                      : 'Requires ${widget.coupon.minOrdersCount} completed order${widget.coupon.minOrdersCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ],
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.orange.shade50,
                  ),
                  child: Text(
                    widget.coupon.code,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _copied
                    ? Container(
                        key: const ValueKey('copied'),
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.isAr ? 'تم النسخ' : 'Copied!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('copy'),
                        onTap: _copyCode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 9,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.kPrimaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.copy,
                                color: Colors.black,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.isAr ? 'نسخ' : 'Copy',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
