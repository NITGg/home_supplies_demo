import 'package:flutter/material.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';

/// Controls which painting style [HighlighterWidget] uses.
enum HighlighterStyle {
  /// Classic full-block stroke — the whole text area is filled with a
  /// translucent, organic marker stroke.
  full,

  /// Thin underline — a narrow band that rises from the text baseline,
  /// mimicking a highlighter drawn *under* the text rather than across it.
  /// Covers roughly the bottom third of the text height.
  underline,
}

/// A reusable widget that wraps [child] with a phosphoric-yellow highlighter
/// pen stroke effect — perfect for calling out discounted or offer prices.
///
/// Two styles are available via [style]:
/// - [HighlighterStyle.full]      — classic full-block marker stroke
/// - [HighlighterStyle.underline] — thin band at the bottom of the text
///
/// Example — full block:
/// ```dart
/// HighlighterWidget(
///   child: Text('850 ج.م', style: TextStyle(fontWeight: FontWeight.bold)),
/// )
/// ```
///
/// Example — thin underline:
/// ```dart
/// HighlighterWidget(
///   style: HighlighterStyle.underline,
///   child: Text('25 ج.م', style: TextStyle(fontWeight: FontWeight.w700)),
/// )
/// ```
class HighlighterWidget extends StatelessWidget {
  final Widget child;

  /// Base highlight colour. Defaults to phosphoric yellow (#d1fe07).
  final Color color;

  /// Opacity of the stroke (0.0 – 1.0).
  /// Defaults to 0.70 for [HighlighterStyle.full]
  /// and 0.85 for [HighlighterStyle.underline] when not set explicitly.
  final double? opacity;

  /// Horizontal padding inside the stroke.
  final double paddingH;

  /// Vertical padding inside the stroke.
  final double paddingV;

  /// Which painting style to use. Defaults to [HighlighterStyle.full].
  final HighlighterStyle style;

  const HighlighterWidget({
    super.key,
    required this.child,
    this.color = AppColors.kDiscountColor,
    this.opacity,
    this.paddingH = 0.0,
    this.paddingV = 0.0,
    this.style = HighlighterStyle.full,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOpacity = opacity ??
        (style == HighlighterStyle.underline ? 0.88 : 0.70);

    return CustomPaint(
      painter: style == HighlighterStyle.underline
          ? _HighlighterUnderlinePainter(
        color: color.withOpacity(effectiveOpacity),
      )
          : _HighlighterPainter(
        color: color.withOpacity(effectiveOpacity),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: paddingH,
          vertical: paddingV,
        ),
        child: child,
      ),
    );
  }
}

// ── Full block painter ────────────────────────────────────────────────────────

/// Paints an organic, hand-drawn style highlighter stroke using cubic bezier
/// curves. The top edge dips slightly and the bottom edge mirrors it so the
/// stroke looks like it was drawn quickly across the text.
class _HighlighterPainter extends CustomPainter {
  final Color color;

  const _HighlighterPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
    // Soft blur gives the wax-like, semi-transparent feel of a real marker.
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);

    final w = size.width;
    final h = size.height;

    final path = Path();

    // ── Top edge: slight dip in the middle, raised at both ends ────────────
    path.moveTo(-5, h * 0.10);
    path.cubicTo(
      w * 0.20, -2.0,   // control point 1 — dip starts
      w * 0.60, 1.0,    // control point 2 — recovers
      w + 5, h * 0.05,  // right end slightly raised
    );

    // ── Right soft cap ──────────────────────────────────────────────────────
    path.lineTo(w + 5, h * 0.95);

    // ── Bottom edge: inverse mirror of top ─────────────────────────────────
    path.cubicTo(
      w * 0.65, h + 1.5, // control point 1
      w * 0.28, h - 0.5, // control point 2
      -5, h * 0.90,      // left end
    );

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HighlighterPainter old) => old.color != color;
}

// ── Underline painter ─────────────────────────────────────────────────────────

/// Paints a thin, organic highlighter band that sits only at the bottom of the
/// widget — covering roughly the lower third of the text height.  The edges are
/// slightly wavy so it reads as hand-drawn rather than a mechanical underline.
class _HighlighterUnderlinePainter extends CustomPainter {
  final Color color;

  const _HighlighterUnderlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    final w = size.width;
    final h = size.height;

    // The band starts at ~62 % of the widget height, covering the bottom ~38 %.
    final bandTop = h * 0.62;

    final path = Path();

    // ── Top edge of band: gentle organic wave ───────────────────────────────
    path.moveTo(-3, bandTop + h * 0.05);
    path.cubicTo(
      w * 0.28, bandTop - h * 0.04, // slight dip at first third
      w * 0.62, bandTop + h * 0.02, // gentle recovery
      w + 3, bandTop - h * 0.01,    // right end marginally lower
    );

    // ── Right cap ────────────────────────────────────────────────────────────
    path.lineTo(w + 3, h + 2.0);

    // ── Bottom edge: inverse, slightly lower variation ───────────────────────
    path.cubicTo(
      w * 0.68, h + 3.0, // control point 1
      w * 0.32, h + 1.5, // control point 2
      -3, h + 2.0,       // left end
    );

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HighlighterUnderlinePainter old) => old.color != color;
}