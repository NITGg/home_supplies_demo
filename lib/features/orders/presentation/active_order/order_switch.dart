import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tawreedat_courier/l10n/app_localizations.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../data/models/orders_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OrderSwitcherDrawer
//
// A persistent bottom drawer that lists all active orders.
// • Collapsed  → shows a single summary row (count + active order number).
// • Expanded   → shows every order as a tappable row with distance & status.
// • Tapping a row calls [onOrderSelected] and auto-collapses the drawer.
// • Tapping outside the expanded drawer (the scrim) collapses it.
// • Swiping down on the drawer collapses it.
// ─────────────────────────────────────────────────────────────────────────────

class OrderSwitcherDrawer extends StatefulWidget {
  const OrderSwitcherDrawer({
    super.key,
    required this.orders,
    required this.selectedIndex,
    required this.onOrderSelected,
    this.courierPosition,
  });

  final List<OrderModel> orders;
  final int selectedIndex;
  final ValueChanged<int> onOrderSelected;

  /// When provided, distances shown in each row are calculated from here.
  final Position? courierPosition;

  @override
  State<OrderSwitcherDrawer> createState() => _OrderSwitcherDrawerState();
}

class _OrderSwitcherDrawerState extends State<OrderSwitcherDrawer>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  late final AnimationController _animController;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  // ── Drag-to-close state ────────────────────────────────────────────────────
  double _dragOffset = 0;
  static const double _kDismissThreshold = 60.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Expand / collapse ──────────────────────────────────────────────────────

  void _open() {
    setState(() => _expanded = true);
    _animController.forward();
  }

  void _close() {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _expanded = false);
    });
  }

  void _toggle() => _expanded ? _close() : _open();

  void _selectOrder(int index) {
    widget.onOrderSelected(index);
    _close();
  }

  // ── Distance helpers ───────────────────────────────────────────────────────

  String _distanceLabel(OrderModel order) {
    final pos = widget.courierPosition;
    if (pos == null) return '';

    final lat = order.collectedAt != null
        ? double.tryParse(order.deliveryLat ?? '0') ?? 0
        : double.tryParse(order.pickupLat ?? '0') ?? 0;
    final lng = order.collectedAt != null
        ? double.tryParse(order.deliveryLong ?? '0') ?? 0
        : double.tryParse(order.pickupLong ?? '0') ?? 0;

    final meters = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      lat,
      lng,
    );

    return _formatMeters(meters);
  }

  String _formatMeters(double meters) {
    final km = meters / 1000;
    return km < 1 ? '${meters.round()} ${AppLocalizations.of(context)!.m}' : '${km.toStringAsFixed(1)} ${AppLocalizations.of(context)!.km}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Scrim: tap-outside-to-close ──────────────────────────────────────
        if (_expanded)
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.opaque,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          ),

        // ── Drawer panel ─────────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildPanel(),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    return GestureDetector(
      // Swipe-down to close
      onVerticalDragUpdate: (details) {
        if (!_expanded) return;
        if (details.delta.dy > 0) {
          setState(() => _dragOffset += details.delta.dy);
        }
      },
      onVerticalDragEnd: (details) {
        if (_dragOffset > _kDismissThreshold ||
            (details.primaryVelocity ?? 0) > 400) {
          _dragOffset = 0;
          _close();
        } else {
          setState(() => _dragOffset = 0);
        }
      },
      child: Transform.translate(
        offset: Offset(0, _dragOffset.clamp(0.0, double.infinity)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              _buildSummaryRow(),
              // Animated list expansion
              ClipRect(
                child: SizeTransition(
                  sizeFactor: _slideAnim,
                  axisAlignment: -1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(height: 1, thickness: 0.5),
                      _buildOrderList(),
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

  // ── Handle ─────────────────────────────────────────────────────────────────

  Widget _buildHandle() {
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: _expanded ? 48 : 32,
            height: 3,
            decoration: BoxDecoration(
              color: _expanded ? AppColors.kPrimaryColor : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  // ── Summary row (always visible) ───────────────────────────────────────────

  Widget _buildSummaryRow() {
    final selected = widget.orders[widget.selectedIndex];
    final count = widget.orders.length;
    final dist = _distanceLabel(selected);

    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        child: Row(
          children: [
            // Order count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.kPrimaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count ${AppLocalizations.of(context)!.orders}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Active order info
            Expanded(
              child: Text(
                    selected.orderNumber,
                style: AppTextStyles.bold14.copyWith(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Chevron
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Order list (expanded) ──────────────────────────────────────────────────

  Widget _buildOrderList() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          widget.orders.length,
              (index) => _buildOrderRow(index),
        ),
      ),
    );
  }

  Widget _buildOrderRow(int index) {
    final order = widget.orders[index];
    final isSelected = index == widget.selectedIndex;
    final isCollected = order.collectedAt != null;
    final dist = _distanceLabel(order);

    return GestureDetector(
      onTap: () => _selectOrder(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.kPrimaryColor.withOpacity(0.06)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.kPrimaryColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Index circle
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.kPrimaryColor
                    : Colors.grey.shade100,
                border: Border.all(
                  color: isSelected
                      ? AppColors.kPrimaryColor
                      : Colors.grey.shade300,
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Order number + destination
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: AppTextStyles.bold14.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _destinationLabel(order),
                    style: AppTextStyles.regular14.copyWith(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Distance + status pill
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (dist.isNotEmpty)
                  Text(
                    dist,
                    style: AppTextStyles.bold14.copyWith(fontSize: 12),
                  ),
                const SizedBox(height: 3),
                _StatusPill(isCollected: isCollected),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _destinationLabel(OrderModel order) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final area = isArabic
        ? (order.collectedAt != null
        ? order.deliveryArea?.nameAr ?? ''
        : order.pickupArea?.nameAr ?? '')
        : (order.collectedAt != null
        ? order.deliveryArea?.name ?? ''
        : order.pickupArea?.name ?? '');
    final customer = order.customer?.fullName ?? '';
    return '$area · $customer';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusPill — small colored badge
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isCollected});

  final bool isCollected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isCollected ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isCollected
            ? AppLocalizations.of(context)!.delivery
            : AppLocalizations.of(context)!.pickup,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isCollected ? Colors.green.shade700 : Colors.orange.shade700,
        ),
      ),
    );
  }
}