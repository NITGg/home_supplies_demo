import 'package:flutter/material.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/order_model.dart';

class OrderRouteSection extends StatefulWidget {
  final Order order;

  const OrderRouteSection({
    super.key,
    required this.order,
  });

  @override
  State<OrderRouteSection> createState() => _OrderRouteSectionState();
}

class _OrderRouteSectionState extends State<OrderRouteSection>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      _isExpanded ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // ── Header / toggle row ──
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.route_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  // Delivery address preview while collapsed
                  if (!_isExpanded)
                    Flexible(
                      child: Text(
                        widget.order.deliveryAddressDescription??'',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.regular14.copyWith(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Collapsible body ──
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _LocationRow(
                        icon: Icons.store_outlined,
                        label: l10n?.pickup ?? 'Pickup',
                        address: widget.order.pickupAddressDescription??'',
                        color: Colors.green,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 1.5,
                              height: 16,
                              color: Colors.grey.shade300,
                              margin: const EdgeInsets.only(left: 11),
                            ),
                          ],
                        ),
                      ),
                      _LocationRow(
                        icon: Icons.location_on,
                        label: l10n?.delivery ?? 'Delivery',
                        address: widget.order.deliveryAddressDescription??'',
                        color: Colors.blue,
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

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String address;
  final Color color;

  const _LocationRow({
    required this.icon,
    required this.label,
    required this.address,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bold14.copyWith(
                  fontSize: 11,
                  color: color,
                ),
              ),
              Text(
                address,
                style: AppTextStyles.regular14.copyWith(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}