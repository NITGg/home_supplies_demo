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
// Fades in on first appearance, then scrolls continuously forever.
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
      duration: const Duration(milliseconds: 800),
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
            child: GestureDetector(
              onTap: () => showCouponsDialog(context),
              child: _ContinuousTicker(coupons: state.activeCoupons),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void showCouponsDialog(BuildContext context) {
    final isAr = AppLocalizations.of(context)?.localeName == 'ar';
    final cubit = context.read<CouponCubit>(); // grab the existing cubit
    cubit.loadCoupons(); // trigger the load

    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit, // reuse it — don't create a new one
        child: CouponsDialog(isAr: isAr ?? false),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coupons Dialog
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
              final coupons = state.activeCoupons;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  const SizedBox(height: 16),
                  _list(context, coupons),
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
        itemBuilder: (context, index) =>
            _CouponCard(coupon: coupons[index], isAr: isAr),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coupon Card inside dialog
// ─────────────────────────────────────────────────────────────────────────────

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
      // ── Scope-aware target label ────────────────────────────────────────
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
          Row(
            children: [
              // Dashed code box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white,
                      style: BorderStyle.solid,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.orange.shade50,
                  ),
                  child: Text(
                    widget.coupon.code,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Copy button
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

// ─────────────────────────────────────────────────────────────────────────────
// Label builder
// ─────────────────────────────────────────────────────────────────────────────

String _labelFor(Coupon coupon, bool isAr) {
  if (isAr) {
    final buf = StringBuffer('استخدم كود ${coupon.code} واحصل على ');
    if (coupon.isWalletCredit) {
      if (coupon.walletAmountCents > 0) buf.write('${coupon.walletAmount.toStringAsFixed(0)} جنيه');
      if (coupon.walletPoints > 0) buf.write(' + ${coupon.walletPoints} نقطة');
    } else if (coupon.discountValue != null) {
      final target = coupon.isDeliveryFeeDiscount ? 'على رسوم التوصيل' : 'على طلبك';
      buf.write(coupon.isPercentDiscount
          ? 'خصم ${coupon.discountValue!.toStringAsFixed(0)}٪ $target'
          : 'خصم ${coupon.discountValue!.toStringAsFixed(0)} جنيه $target');
    }
    return buf.toString();
  } else {
    final buf = StringBuffer('Use code ${coupon.code} & get ');
    if (coupon.isWalletCredit) {
      if (coupon.walletAmountCents > 0) buf.write('${coupon.walletAmount.toStringAsFixed(0)} EGP');
      if (coupon.walletPoints > 0) buf.write(' + ${coupon.walletPoints} pts');
    } else if (coupon.discountValue != null) {
      final target = coupon.isDeliveryFeeDiscount ? 'off delivery fee' : 'off your order';
      buf.write(coupon.isPercentDiscount
          ? '${coupon.discountValue!.toStringAsFixed(0)}% $target'
          : '${coupon.discountValue!.toStringAsFixed(0)} EGP $target');
    }
    return buf.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class _ContinuousTicker extends StatefulWidget {
  final List<Coupon> coupons;

  const _ContinuousTicker({required this.coupons});

  @override
  State<_ContinuousTicker> createState() => _ContinuousTickerState();
}

class _ContinuousTickerState extends State<_ContinuousTicker>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  static const double _speed = 30.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _elapsed = elapsed);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context)!.localeName == 'ar';
    final labels = widget.coupons.map((c) => _labelFor(c, isAr)).toList();

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox.expand(
          child: CustomPaint(
            painter: _TickerPainter(
              labels: labels,
              isRtl: isAr,
              speed: _speed,
              elapsed: _elapsed,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segment
// ─────────────────────────────────────────────────────────────────────────────

class _Segment {
  final String text;
  final TextPainter painter;

  _Segment(this.text, this.painter);

  double get width => painter.width;

  double get height => painter.height;
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

class _TickerPainter extends CustomPainter {
  final List<String> labels;
  final bool isRtl;
  final double speed;
  final Duration elapsed;

  _TickerPainter({
    required this.labels,
    required this.isRtl,
    required this.speed,
    required this.elapsed,
  });

  static const TextStyle _style = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
    letterSpacing: 0.1,
  );

  static const double _dotPadding = 14.0;
  static const double _dotRadius = 3.0;
  static const double _separatorWidth = _dotPadding * 2 + _dotRadius * 2;

  final Paint _dotPaint = Paint()..color = Colors.orangeAccent;

  static List<String>? _cachedLabels;
  static List<_Segment>? _cachedSegments;
  static double _cachedStripWidth = 0;

  List<_Segment> _getSegments() {
    if (_cachedLabels != null &&
        _cachedLabels!.length == labels.length &&
        _cachedLabels!.join() == labels.join() &&
        _cachedSegments != null) {
      return _cachedSegments!;
    }

    double totalWidth = 0;
    final segments = <_Segment>[];

    for (final label in labels) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: _style),
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        maxLines: 1,
      )..layout();

      segments.add(_Segment(label, tp));
      totalWidth += tp.width + _separatorWidth;
    }

    _cachedLabels = List.of(labels);
    _cachedSegments = segments;
    _cachedStripWidth = totalWidth;

    return segments;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final segments = _getSegments();
    final stripWidth = _cachedStripWidth;
    if (stripWidth <= 0 || size.width <= 0) return;

    final seconds = elapsed.inMicroseconds / 1e6;
    final offset = (seconds * speed) % stripWidth;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    _drawStrip(canvas, size, segments, isRtl ? offset : -offset);
    _drawStrip(
      canvas,
      size,
      segments,
      isRtl ? offset - stripWidth : stripWidth - offset,
    );

    canvas.restore();
  }

  void _drawStrip(
    Canvas canvas,
    Size size,
    List<_Segment> segments,
    double startX,
  ) {
    double x = startX;
    final centerY = size.height / 2;

    for (final seg in segments) {
      final textY = centerY - seg.height / 2;
      seg.painter.paint(canvas, Offset(x, textY));
      x += seg.width;

      x += _dotPadding + _dotRadius;
      canvas.drawCircle(Offset(x, centerY), _dotRadius, _dotPaint);
      x += _dotRadius + _dotPadding;
    }
  }

  @override
  bool shouldRepaint(covariant _TickerPainter old) =>
      old.elapsed != elapsed ||
      old.labels.join() != labels.join() ||
      old.isRtl != isRtl;
}
