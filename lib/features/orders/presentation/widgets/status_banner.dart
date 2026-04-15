import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';
import '../../data/models/order_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Status descriptor — add new statuses here and nowhere else.
// Priority: lower number = shown first when multiple statuses are present.
// ─────────────────────────────────────────────────────────────────────────────

class _StatusDescriptor {
  final String assetPath;
  final String Function(BuildContext) label;
  final Color accent;

  const _StatusDescriptor({
    required this.assetPath,
    required this.label,
    required this.accent,
  });
}

const Map<String, ({int priority, _StatusDescriptor descriptor})>
_kStatusMap = {
  'IN_PROGRESS': (
  priority: 2,                          // ← bumped down; out-for-delivery wins
  descriptor: _StatusDescriptor(
    assetPath: 'assets/animation_json/Packaging_in_Progress.json',
    label: _labelInProgress,
    accent: Color(0xFF21ABF5),
  ),
  ),
  'PENDING': (
  priority: 3,
  descriptor: _StatusDescriptor(
    assetPath: 'assets/animation_json/Searching.json',
    label: _labelPending,
    accent: Color(0xFFFF9800),
  ),
  ),
  // Virtual status — same API value as IN_PROGRESS but collectedAt is set
  'OUT_FOR_DELIVERY': (
  priority: 1,
  descriptor: _StatusDescriptor(
    assetPath: 'assets/animation_json/courier_on_the_way.json',
    label: _labelOutForDelivery,
    accent: Color(0xFF2196F3),
  ),
  ),
};

// Label functions — extracted so they can be const-referenced above.
String _labelInProgress(BuildContext ctx) =>
    AppLocalizations.of(ctx)!.preparingOrder;

String _labelPending(BuildContext ctx) =>
    AppLocalizations.of(ctx)!.findingCourier;

String _labelOutForDelivery(BuildContext ctx) =>
    AppLocalizations.of(ctx)!.outForDelivery; // add to .arb files
// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

/// Displays an animated status hint at the top of the active-orders list.
///
/// Pass the current [orders] list. The widget selects the highest-priority
/// status present and renders the matching Lottie + label. It returns
/// [SizedBox.shrink] when no recognisable status is found, so it is always
/// safe to include unconditionally.
///
/// **Performance notes**
/// - Wrapped in [RepaintBoundary] → isolated from list repaints.
/// - [AnimationController] lives inside [LottieBuilder]; no extra controller.
/// - [_resolveStatus] runs in O(n) over the order list — negligible.
class OrderStatusBanner extends StatelessWidget {
  final List<Order> orders;

  const OrderStatusBanner({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveStatus(orders);
    if (resolved == null) return const SizedBox.shrink();

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: _BannerContent(descriptor: resolved),
      ),
    );
  }

  /// Returns the descriptor for the highest-priority status found in [orders],
  /// or null if none of the orders have a recognised status.
  static _StatusDescriptor? _resolveStatus(List<Order> orders) {
    ({int priority, _StatusDescriptor descriptor})? best;

    for (final order in orders) {
      var key = order.status?.toUpperCase();
      if (key == null) continue;

      // Treat IN_PROGRESS + collectedAt set as a virtual OUT_FOR_DELIVERY status
      if (key == 'IN_PROGRESS' && order.collectedAt != null) {
        key = 'OUT_FOR_DELIVERY';
      }

      final entry = _kStatusMap[key];
      if (entry == null) continue;
      if (best == null || entry.priority < best.priority) {
        best = entry;
      }
    }

    return best?.descriptor;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private animated card
// ─────────────────────────────────────────────────────────────────────────────

class _BannerContent extends StatefulWidget {
  final _StatusDescriptor descriptor;

  const _BannerContent({required this.descriptor});

  @override
  State<_BannerContent> createState() => _BannerContentState();
}

class _BannerContentState extends State<_BannerContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  String? _currentAsset;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _currentAsset = widget.descriptor.assetPath;
    _fadeController.forward();
  }

  @override
  void didUpdateWidget(_BannerContent old) {
    super.didUpdateWidget(old);
    // Animate out → swap asset → animate in only when the asset actually changes.
    if (old.descriptor.assetPath != widget.descriptor.assetPath) {
      _fadeController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _currentAsset = widget.descriptor.assetPath);
        _fadeController.forward();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.descriptor.accent;
    final label = widget.descriptor.label(context);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.08), accent.withOpacity(0.03)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(0.25), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Lottie — fixed square so layout never jumps.
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: _currentAsset != null
                        ? Lottie.asset(
                            _currentAsset!,
                            repeat: true,
                            frameRate: FrameRate(30),
                            // Decode at 2× logical pixels for crispness on
                            // high-density screens without wasting memory.
                            width: 80,
                            height: 80,
                            fit: BoxFit.fitWidth,
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      textAlign: TextAlign.center,
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: accent.withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
