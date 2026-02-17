import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../data/models/coupons_model.dart';
import '../manager/coupons_cubit.dart';
import '../manager/ocupons_states.dart';

class CouponTickerTitle extends StatelessWidget {
  const CouponTickerTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CouponCubit, CouponState>(
      builder: (context, state) {
        if (state is CouponsLoaded && state.activeCoupons.isNotEmpty) {
          return _ContinuousTicker(coupons: state.activeCoupons);
        }
        return const SizedBox.shrink();
      },
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
      if (coupon.walletAmountCents > 0) {
        buf.write('${coupon.walletAmount.toStringAsFixed(0)} جنيه');
      }
      if (coupon.walletPoints > 0) buf.write(' + ${coupon.walletPoints} نقطة');
    } else {
      if (coupon.discountValue != null) {
        buf.write(
          coupon.isPercentDiscount
              ? 'خصم ${coupon.discountValue!.toStringAsFixed(0)}٪'
              : 'خصم ${coupon.discountValue!.toStringAsFixed(0)} جنيه',
        );
      }
    }
    return buf.toString();
  } else {
    final buf = StringBuffer('Use code ${coupon.code} & get ');
    if (coupon.isWalletCredit) {
      if (coupon.walletAmountCents > 0) {
        buf.write('${coupon.walletAmount.toStringAsFixed(0)} EGP');
      }
      if (coupon.walletPoints > 0) buf.write(' + ${coupon.walletPoints} pts');
    } else {
      if (coupon.discountValue != null) {
        buf.write(
          coupon.isPercentDiscount
              ? '${coupon.discountValue!.toStringAsFixed(0)}% off'
              : '${coupon.discountValue!.toStringAsFixed(0)} EGP off',
        );
      }
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

  static const double _speed = 40.0;

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
// A measured segment: TextPainter (easy, correct width) + the raw text
// ─────────────────────────────────────────────────────────────────────────────

class _Segment {
  final String text;
  final TextPainter painter;

  _Segment(this.text, this.painter);

  double get width => painter.width;

  double get height => painter.height;
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter — uses TextPainter (not ui.Paragraph) so width is always correct,
// draws each label + an orange dot separator, two strips for seamless loop.
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

  static const double _dotPadding = 14.0; // space each side of dot
  static const double _dotRadius = 3.0;
  static const double _separatorWidth = _dotPadding * 2 + _dotRadius * 2;

  final Paint _dotPaint = Paint()..color = Colors.deepOrange;

  // ── Cache ─────────────────────────────────────────────────────────────────
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
      )..layout(); // no width constraint → measures full intrinsic width

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

    // Two strips — copy 1 and copy 2 offset by one stripWidth
    _drawStrip(canvas, size, segments, stripWidth, isRtl ? offset : -offset);
    _drawStrip(
      canvas,
      size,
      segments,
      stripWidth,
      isRtl ? offset - stripWidth : stripWidth - offset,
    );

    canvas.restore();
  }

  void _drawStrip(
    Canvas canvas,
    Size size,
    List<_Segment> segments,
    double stripWidth,
    double startX,
  ) {
    double x = startX;
    final centerY = size.height / 2;

    for (final seg in segments) {
      final textY = centerY - seg.height / 2;

      // Paint the text using TextPainter — always LTR draw position,
      // RTL text is handled internally by TextPainter direction setting.
      seg.painter.paint(canvas, Offset(x, textY));
      x += seg.width;

      // Orange dot separator
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
