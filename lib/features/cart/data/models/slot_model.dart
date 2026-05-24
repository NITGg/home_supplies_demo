// ── Working hour window ───────────────────────────────────────────────────────

/// A single open/close window from the day's working_hours array.
/// Used only for display and as the fallback selectable range when no
/// pre-configured slots exist for that day.
class DayWorkingHour {
  final String open;
  final String close;

  const DayWorkingHour({required this.open, required this.close});

  factory DayWorkingHour.fromJson(Map<String, dynamic> json) => DayWorkingHour(
    open: json['open'] as String,
    close: json['close'] as String,
  );
}

// ── Slot ──────────────────────────────────────────────────────────────────────

/// A pre-configured capacity window returned by the slot-status endpoint.
///
/// Mental model:
///   • A slot appears in the response only when it has been configured in
///     the back-end (it may have 0, some, or max orders).
///   • [isFull] is the authoritative flag — when true the slot cannot accept
///     new orders regardless of the [currentOrders] count.
///   • A day whose [DaySlotModel.slots] list is empty but [isClosed] is false
///     has no structured capacity management: any time within the working
///     hours is freely available.
class SlotModel {
  final int id;
  final String timeFrom;
  final String timeTo;
  final int maxOrders;
  final int currentOrders;
  final bool isFull;

  const SlotModel({
    required this.id,
    required this.timeFrom,
    required this.timeTo,
    required this.maxOrders,
    required this.currentOrders,
    required this.isFull,
  });

  factory SlotModel.fromJson(Map<String, dynamic> json) => SlotModel(
    id: json['id'] as int,
    timeFrom: json['time_from'] as String,
    timeTo: json['time_to'] as String,
    maxOrders: json['max_orders'] as int,
    currentOrders: json['current_orders'] as int,
    isFull: json['is_full'] as bool,
  );

  int get fromHour => int.parse(timeFrom.split(':')[0]);
  int get fromMinute => int.parse(timeFrom.split(':')[1]);

  /// Ratio of used capacity, in [0.0, 1.0].  Null when maxOrders is 0.
  double? get fillRatio =>
      maxOrders > 0 ? (currentOrders / maxOrders).clamp(0.0, 1.0) : null;

  /// Returns a DateTime placing this slot's start time on [date].
  DateTime toDateTime(DateTime date) =>
      DateTime(date.year, date.month, date.day, fromHour, fromMinute);
}

// ── Day ───────────────────────────────────────────────────────────────────────

class DaySlotModel {
  final String date; // "2026-05-24"
  final int dayOfWeek;
  final String dayName;
  final bool isToday;
  final bool isClosed;

  /// Full open/close windows for the day — used for display only.
  final List<DayWorkingHour> workingHours;

  /// Pre-configured capacity slots.  May be empty even when the store is open
  /// (meaning no structured slot management for that day).
  final List<SlotModel> slots;

  final int totalOrders;
  final int unslottedOrders;

  const DaySlotModel({
    required this.date,
    required this.dayOfWeek,
    required this.dayName,
    required this.isToday,
    required this.isClosed,
    required this.workingHours,
    required this.slots,
    required this.totalOrders,
    required this.unslottedOrders,
  });

  factory DaySlotModel.fromJson(Map<String, dynamic> json) => DaySlotModel(
    date: json['date'] as String,
    dayOfWeek: json['day_of_week'] as int,
    dayName: json['day_name'] as String,
    isToday: json['is_today'] as bool? ?? false,
    isClosed: json['is_closed'] as bool? ?? false,
    workingHours: (json['working_hours'] as List<dynamic>? ?? [])
        .map((w) => DayWorkingHour.fromJson(w as Map<String, dynamic>))
        .toList(),
    slots: (json['slots'] as List<dynamic>? ?? [])
        .map((s) => SlotModel.fromJson(s as Map<String, dynamic>))
        .toList(),
    totalOrders: json['total_orders'] as int? ?? 0,
    unslottedOrders: json['unslotted_orders'] as int? ?? 0,
  );

  DateTime get dateTime => DateTime.parse(date);

  /// True when the day has pre-configured slot windows.
  bool get hasConfiguredSlots => slots.isNotEmpty;

  /// True when at least one slot can still accept orders.
  bool get hasAvailableSlots => slots.any((s) => !s.isFull);

  /// True when every configured slot is at capacity.
  bool get allSlotsFull =>
      slots.isNotEmpty && slots.every((s) => s.isFull);
}

// ── Top-level response ────────────────────────────────────────────────────────

class SlotStatusData {
  final int storeAddressId;
  final String timezone;
  final List<DaySlotModel> days;

  const SlotStatusData({
    required this.storeAddressId,
    required this.timezone,
    required this.days,
  });

  factory SlotStatusData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return SlotStatusData(
      storeAddressId: data['store_address_id'] as int,
      timezone: data['timezone'] as String,
      days: (data['days'] as List<dynamic>)
          .map((d) => DaySlotModel.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Picker result ─────────────────────────────────────────────────────────────

/// Returned by [showSlotPickerSheet] when the user confirms a selection.
///
/// [dateTime] is always set — it is the slot's start time on the chosen day
/// (or the raw free-pick time when the fallback picker is used).
///
/// [slot] is non-null only when the user picked a pre-configured slot.
/// It is null for free working-hour window selections (no capacity slot exists).
class SlotPickerResult {
  final DateTime dateTime;
  final SlotModel? slot;

  const SlotPickerResult({required this.dateTime, this.slot});
}

// ── Display helpers (used inside the sheet only) ──────────────────────────────

enum SlotAvailability {
  /// No configured slot for this window — completely free.
  free,

  /// Slot exists and has orders, but is not full.
  partial,

  /// Slot is at capacity — cannot be selected.
  full,
}

/// A normalised row displayed in the slot picker regardless of whether it
/// came from a pre-configured [SlotModel] or from a working-hours fallback.
class DisplaySlot {
  /// Null for free working-hour windows that have no configured slot.
  final SlotModel? source;
  final String timeFrom;
  final String timeTo;
  final SlotAvailability availability;

  const DisplaySlot({
    required this.source,
    required this.timeFrom,
    required this.timeTo,
    required this.availability,
  });

  bool get isSelectable => availability != SlotAvailability.full;

  /// Build display rows for [day] using the correct mental model:
  ///
  /// 1. If the day has pre-configured slots → use those as rows.
  ///    Each slot knows its own capacity state.
  /// 2. If the day has no configured slots but is open → fall back to one
  ///    row per working-hour window, all marked as free.
  static List<DisplaySlot> forDay(DaySlotModel day) {
    if (day.hasConfiguredSlots) {
      return day.slots.map((slot) {
        final availability = slot.isFull
            ? SlotAvailability.full
            : slot.currentOrders == 0
            ? SlotAvailability.free
            : SlotAvailability.partial;

        return DisplaySlot(
          source: slot,
          timeFrom: slot.timeFrom,
          timeTo: slot.timeTo,
          availability: availability,
        );
      }).toList();
    }

    // No configured slots — the whole working window is open.
    return day.workingHours
        .map((wh) => DisplaySlot(
      source: null,
      timeFrom: wh.open,
      timeTo: wh.close,
      availability: SlotAvailability.free,
    ))
        .toList();
  }
}