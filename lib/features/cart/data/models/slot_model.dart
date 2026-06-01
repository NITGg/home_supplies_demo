// ── Delivery window models ─────────────────────────────────────────────────────
//
// Covers two endpoints:
//
//  1.  GET supplier/product/get-supplier-product-delivery-windows/:spId
//      Used in product card / details screen to show ORDER and DELIVERY windows.
//
//  2.  GET /orders/cart/delivery-slots?date=YYYY-MM-DD
//      Used in the cart checkout flow to show available delivery time slots for
//      a chosen date.

// ── 1.  Product delivery windows ─────────────────────────────────────────────

/// A single ORDER or DELIVERY window defined by the supplier for a product.
///
/// [dayOfWeek] uses the JS/ISO Sunday-based convention:
///   0 = Sunday, 1 = Monday, … 5 = Friday, 6 = Saturday
class DeliveryWindow {
  final int id;
  final int supplierProductId;

  /// 'ORDER'    → customer can place orders during this window
  /// 'DELIVERY' → orders will be fulfilled during this window
  final String windowType;

  /// JS weekday: 0 = Sunday … 6 = Saturday
  final int dayOfWeek;
  final String timeFrom; // "08:00"
  final String timeTo;   // "12:00"
  final int? maxOrders;

  const DeliveryWindow({
    required this.id,
    required this.supplierProductId,
    required this.windowType,
    required this.dayOfWeek,
    required this.timeFrom,
    required this.timeTo,
    this.maxOrders,
  });

  factory DeliveryWindow.fromJson(Map<String, dynamic> json) => DeliveryWindow(
        id: json['id'] as int,
        supplierProductId: json['supplier_product_id'] as int,
        windowType: json['window_type'] as String,
        dayOfWeek: json['day_of_week'] as int,
        timeFrom: json['time_from'] as String,
        timeTo: json['time_to'] as String,
        maxOrders: json['max_orders'] as int?,
      );

  bool get isOrder => windowType == 'ORDER';
  bool get isDelivery => windowType == 'DELIVERY';

  /// Human-readable short day name (Sunday-based, matching dayOfWeek).
  String get dayName => const [
        'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
      ][dayOfWeek];

  String get fullDayName => const [
        'Sunday', 'Monday', 'Tuesday', 'Wednesday',
        'Thursday', 'Friday', 'Saturday',
      ][dayOfWeek];

  String get timeRange => '$timeFrom – $timeTo';
}

/// Full response from the product delivery-windows endpoint.
class ProductDeliveryWindowsData {
  final bool requiresDeliveryWindows;
  final List<DeliveryWindow> windows;

  const ProductDeliveryWindowsData({
    required this.requiresDeliveryWindows,
    required this.windows,
  });

  factory ProductDeliveryWindowsData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return ProductDeliveryWindowsData(
      requiresDeliveryWindows: data['requires_delivery_windows'] as bool? ?? false,
      windows: (data['windows'] as List<dynamic>? ?? [])
          .map((w) => DeliveryWindow.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }

  List<DeliveryWindow> get orderWindows =>
      windows.where((w) => w.isOrder).toList();

  List<DeliveryWindow> get deliveryWindows =>
      windows.where((w) => w.isDelivery).toList();

  /// Set of JS weekday ints (0=Sun…6=Sat) that have at least one DELIVERY window.
  Set<int> get deliveryDaysOfWeek =>
      deliveryWindows.map((w) => w.dayOfWeek).toSet();

  /// Set of JS weekday ints that have at least one ORDER window.
  Set<int> get orderDaysOfWeek =>
      orderWindows.map((w) => w.dayOfWeek).toSet();

  /// Groups ORDER windows by day-of-week for display purposes.
  Map<int, List<DeliveryWindow>> get orderWindowsByDay {
    final map = <int, List<DeliveryWindow>>{};
    for (final w in orderWindows) {
      (map[w.dayOfWeek] ??= []).add(w);
    }
    return map;
  }

  /// Groups DELIVERY windows by day-of-week for display purposes.
  Map<int, List<DeliveryWindow>> get deliveryWindowsByDay {
    final map = <int, List<DeliveryWindow>>{};
    for (final w in deliveryWindows) {
      (map[w.dayOfWeek] ??= []).add(w);
    }
    return map;
  }

  /// Returns the next N valid DELIVERY dates starting from [from], restricted
  /// to days that have a DELIVERY window configured.
  List<DateTime> nextDeliveryDates({
    required DateTime from,
    int count = 30,
  }) {
    final validDays = deliveryDaysOfWeek;
    if (validDays.isEmpty) return [];

    final result = <DateTime>[];
    var cursor = DateTime(from.year, from.month, from.day);

    while (result.length < count) {
      // Dart weekday: 1=Mon…7=Sun → convert to JS: Mon=1, Sun=0
      final jsDay = cursor.weekday == 7 ? 0 : cursor.weekday;
      if (validDays.contains(jsDay)) {
        result.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }
}

// ── 2.  Cart delivery slots ───────────────────────────────────────────────────

/// A single available delivery time slot for a chosen date.
/// Returned by GET /orders/cart/delivery-slots?date=YYYY-MM-DD
class CartDeliverySlot {
  final String timeFrom; // "09:00"
  final String timeTo;   // "18:00"
  final int remaining;   // 0 = full, do not allow selection

  const CartDeliverySlot({
    required this.timeFrom,
    required this.timeTo,
    required this.remaining,
  });

  factory CartDeliverySlot.fromJson(Map<String, dynamic> json) =>
      CartDeliverySlot(
        timeFrom: json['time_from'] as String,
        timeTo: json['time_to'] as String,
        remaining: json['remaining'] as int? ?? 0,
      );

  bool get isFull => remaining == 0;
  bool get isAvailable => remaining > 0;

  String get timeRange => '$timeFrom – $timeTo';

  /// Builds the DateTime to pass as order_schedule_at for [date].
  DateTime toScheduledAt(DateTime date) {
    final parts = timeFrom.split(':');
    return DateTime(
      date.year, date.month, date.day,
      int.parse(parts[0]), int.parse(parts[1]),
    );
  }
}

/// Full response from GET /orders/cart/delivery-slots?date=YYYY-MM-DD
class CartDeliverySlotsResponse {
  /// true  → this cart contains products that require delivery window scheduling
  /// false → normal cart, use existing schedule flow
  final bool isScheduledWindows;
  final DateTime date;
  final List<CartDeliverySlot> slots;

  const CartDeliverySlotsResponse({
    required this.isScheduledWindows,
    required this.date,
    required this.slots,
  });

  factory CartDeliverySlotsResponse.fromJson(Map<String, dynamic> json) =>
      CartDeliverySlotsResponse(
        isScheduledWindows: json['is_scheduled_windows'] as bool? ?? false,
        date: DateTime.parse(json['date'] as String),
        slots: (json['slots'] as List<dynamic>? ?? [])
            .map((s) => CartDeliverySlot.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  List<CartDeliverySlot> get availableSlots =>
      slots.where((s) => s.isAvailable).toList();
}
