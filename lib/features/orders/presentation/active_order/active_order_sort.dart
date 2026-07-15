// ─────────────────────────────────────────────────────────────────────────────
// active_order_sort.dart
//
// Drop this next to active_order_helpers.dart and import it in
// active_order_screen.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:geolocator/geolocator.dart';
import '../../data/models/orders_model.dart';

/// Returns a NEW list sorted by distance from [courierPosition].
///
/// For orders that have already been collected the distance is measured to the
/// *delivery* waypoint; for orders still awaiting pickup it is measured to the
/// *pickup* waypoint.  This way the nearest *next action* always appears first.
///
/// Falls back to the original list order when [courierPosition] is null.
List<OrderModel> sortOrdersByNextWaypoint(
    List<OrderModel> orders,
    Position? courierPosition,
    ) {
  if (courierPosition == null || orders.length <= 1) return orders;

  return [...orders]..sort((a, b) {
    final dA = _distanceToNextWaypoint(a, courierPosition);
    final dB = _distanceToNextWaypoint(b, courierPosition);
    return dA.compareTo(dB);
  });
}

double _distanceToNextWaypoint(OrderModel order, Position from) {
  final double lat;
  final double lng;

  if (order.collectedAt != null) {
    lat = double.tryParse(order.deliveryLat ?? '0') ?? 0;
    lng = double.tryParse(order.deliveryLong ?? '0') ?? 0;
  } else {
    lat = double.tryParse(order.pickupLat ?? '0') ?? 0;
    lng = double.tryParse(order.pickupLong ?? '0') ?? 0;
  }

  return Geolocator.distanceBetween(
    from.latitude,
    from.longitude,
    lat,
    lng,
  );
}
