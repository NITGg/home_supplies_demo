// ── Working hour window ───────────────────────────────────────────────────────

/// A single open/close window from the day's working_hours array.
class DayWorkingHour {
  final String open;
  final String close;

  const DayWorkingHour({required this.open, required this.close});

  factory DayWorkingHour.fromJson(Map<String, dynamic> json) => DayWorkingHour(
    open: json['open'] as String,
    close: json['close'] as String,
  );
}

// ── Weekly schedule ───────────────────────────────────────────────────────────

/// The schedule for a single weekday inside [WeeklySchedule].
///
/// The API key is an integer string "0"–"6" where:
///   0 = Sunday, 1 = Monday, … 5 = Friday, 6 = Saturday
/// (i.e. JS/ISO Sunday-based week).
///
/// Dart's [DateTime.weekday] is 1 = Monday … 7 = Sunday, so a conversion is
/// needed — see [WeeklySchedule.workingHoursFor].
class WeeklyDaySchedule {
  final bool isClosed;

  /// The open/close windows for the day (may be empty when [isClosed]).
  final List<DayWorkingHour> slots;

  const WeeklyDaySchedule({required this.isClosed, required this.slots});

  factory WeeklyDaySchedule.fromJson(Map<String, dynamic> json) =>
      WeeklyDaySchedule(
        isClosed: json['is_closed'] as bool? ?? false,
        slots: (json['slots'] as List<dynamic>? ?? [])
            .map((s) => DayWorkingHour.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

/// The full 7-day weekly template returned under `data.workingHours`.
///
/// The API uses a Sunday-based JS weekday index (0 = Sun, 6 = Sat).
/// [workingHoursFor] converts a Dart [DateTime.weekday] (1 = Mon … 7 = Sun)
/// to the correct API key before looking up the schedule.
class WeeklySchedule {
  final String timezone;

  /// Keyed 0–6 (Sun–Sat, JS convention).
  final Map<int, WeeklyDaySchedule> days;

  const WeeklySchedule({required this.timezone, required this.days});

  factory WeeklySchedule.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as Map<String, dynamic>;
    return WeeklySchedule(
      timezone: json['timezone'] as String? ?? '',
      days: {
        for (final entry in rawDays.entries)
          int.parse(entry.key):
          WeeklyDaySchedule.fromJson(entry.value as Map<String, dynamic>),
      },
    );
  }

  /// Returns the [WeeklyDaySchedule] for [dartWeekday] (1 = Mon … 7 = Sun).
  ///
  /// Dart → API mapping:
  ///   Mon=1 → 1, Tue=2 → 2, Wed=3 → 3, Thu=4 → 4, Fri=5 → 5,
  ///   Sat=6 → 6, Sun=7 → 0
  WeeklyDaySchedule? workingHoursFor(int dartWeekday) {
    final apiKey = dartWeekday == 7 ? 0 : dartWeekday;
    return days[apiKey];
  }
}

// ── Slot ──────────────────────────────────────────────────────────────────────

/// A booked capacity window returned by the slot-status endpoint.
///
/// Mental model (critical):
///   • The API only returns slots that have at least one order.
///   • A time window NOT present in [DaySlotModel.slots] is completely free.
///   • [isFull] — when true the slot cannot accept new orders.
///   • A day with an empty [DaySlotModel.slots] list has zero bookings yet;
///     every window generated from its working hours is available.
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

  /// Full open/close windows for the day.
  final List<DayWorkingHour> workingHours;

  /// Booked capacity slots returned by the API.  May be empty — that means
  /// no bookings exist yet, NOT that the day is unavailable.
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

  /// True when every generated slot window for this day is at capacity.
  /// Requires [slotDurationMinutes] to generate the windows correctly.
  bool allSlotsFull(int slotDurationMinutes) {
    final generated =
    DisplaySlot.forDay(this, slotDurationMinutes: slotDurationMinutes);
    return generated.isNotEmpty &&
        generated.every((s) => s.availability == SlotAvailability.full);
  }

  /// True when at least one generated slot can still accept orders.
  bool hasAvailableSlots(int slotDurationMinutes) {
    return DisplaySlot.forDay(this, slotDurationMinutes: slotDurationMinutes)
        .any((s) => s.isSelectable);
  }
}

// ── Top-level response ────────────────────────────────────────────────────────

class SlotStatusData {
  final int storeAddressId;
  final String timezone;

  /// Full weekly schedule template from `data.workingHours`.
  /// Used by [daysInRange] to synthesise free days that have no bookings.
  final WeeklySchedule? weeklySchedule;

  final List<DaySlotModel> days;

  const SlotStatusData({
    required this.storeAddressId,
    required this.timezone,
    this.weeklySchedule,
    required this.days,
  });

  factory SlotStatusData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;

    final rawWH = data['workingHours'];
    final WeeklySchedule? weekly = rawWH != null
        ? WeeklySchedule.fromJson(rawWH as Map<String, dynamic>)
        : null;

    return SlotStatusData(
      storeAddressId: data['store_address_id'] as int,
      timezone: data['timezone'] as String,
      weeklySchedule: weekly,
      days: (data['days'] as List<dynamic>)
          .map((d) => DaySlotModel.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  /// FIX: Infers slot duration by taking the MODE (most common duration)
  /// across all booked slots, rather than naively picking the first one.
  ///
  /// This prevents a single anomalous short slot (e.g. a 19-min Friday window)
  /// from poisoning the entire UI's slot grid.  Falls back to 60 minutes when
  /// no bookings exist yet.
  // In SlotStatusData, replace inferredSlotDurationMinutes with:
// In SlotStatusData
  int get inferredSlotDurationMinutes {
    // If backend sends slot_duration_minutes, use it directly
    // (add this field to the model when backend supports it)

    // For wide windows (> 2 hours), break into 2-hour sub-slots
    const subSlotDuration = 120; // 2 hours

    if (weeklySchedule != null) {
      for (final daySched in weeklySchedule!.days.values) {
        if (!daySched.isClosed && daySched.slots.isNotEmpty) {
          final wh = daySched.slots.first;
          final span = _timeToMinutes(wh.close) - _timeToMinutes(wh.open);
          if (span > subSlotDuration) return subSlotDuration;
          if (span > 0) return span;
        }
      }
    }

    // Fallback: mode of booked slot durations
    final counts = <int, int>{};
    for (final day in days) {
      for (final slot in day.slots) {
        final diff = _timeToMinutes(slot.timeTo) - _timeToMinutes(slot.timeFrom);
        if (diff > 0) counts[diff] = (counts[diff] ?? 0) + 1;
      }
    }
    if (counts.isNotEmpty) {
      return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    return 120;
  }

  /// Returns a continuous list of open days from [from] to [to] (inclusive).
  ///
  /// Why this exists:
  ///   The API only returns days that have at least one booking.  A date with
  ///   zero bookings simply does not appear in [days], but it is still fully
  ///   available for selection.  This method fills those gaps:
  ///
  ///   • Dates present in [days] → used as-is (may carry partial/full slots).
  ///   • Dates absent from [days] → synthesised as fully-free open days using
  ///     [weeklySchedule] (when present) for the correct working hours.
  ///     If [weeklySchedule] is absent the legacy day-of-week inference
  ///     fallback is used so the method stays backward compatible.
  ///   • Dates marked [isClosed] in the API are excluded.
  ///   • Dates whose weekly schedule marks them as closed are also excluded.
  List<DaySlotModel> daysInRange({
    required DateTime from,
    required DateTime to,
  }) {
    // Index API days by their date string for O(1) lookup.
    final byDate = <String, DaySlotModel>{
      for (final d in days) d.date: d,
    };

    // Legacy fallback: build a day-of-week → working hours map from known
    // open days.  Only used when [weeklySchedule] is absent.
    // day_of_week in the API matches Dart's DateTime.weekday (1=Mon … 7=Sun).
    final legacyHoursByDow = <int, List<DayWorkingHour>>{};
    if (weeklySchedule == null) {
      for (final d in days) {
        if (!d.isClosed && d.workingHours.isNotEmpty) {
          legacyHoursByDow.putIfAbsent(d.dayOfWeek, () => d.workingHours);
        }
      }
    }

    final result = <DaySlotModel>[];
    var cursor = DateTime(from.year, from.month, from.day);
    final finish = DateTime(to.year, to.month, to.day);

    while (!cursor.isAfter(finish)) {
      final dateStr = _formatDate(cursor);

      final apiDay = byDate[dateStr];
      if (apiDay != null) {
        // The API knows about this date — respect its isClosed flag.
        if (!apiDay.isClosed) result.add(apiDay);
      } else {
        // Not in the API response → no bookings yet; synthesise a free day.
        if (weeklySchedule != null) {
          // Preferred path: use the authoritative weekly template.
          final daySched = weeklySchedule!.workingHoursFor(cursor.weekday);
          if (daySched != null && !daySched.isClosed) {
            result.add(DaySlotModel(
              date: dateStr,
              dayOfWeek: cursor.weekday,
              dayName: _weekdayName(cursor.weekday),
              isToday: _isToday(cursor),
              isClosed: false,
              workingHours: daySched.slots,
              slots: [], // no bookings = every generated window is free
              totalOrders: 0,
              unslottedOrders: 0,
            ));
          }
          // If daySched is null or closed the store doesn't open that day;
          // omit the date entirely.
        } else {
          // Legacy fallback: infer working hours from other days with the
          // same weekday.  Less reliable — kept for backward compatibility.
          final wh = legacyHoursByDow[cursor.weekday];
          if (wh != null) {
            result.add(DaySlotModel(
              date: dateStr,
              dayOfWeek: cursor.weekday,
              dayName: _weekdayName(cursor.weekday),
              isToday: _isToday(cursor),
              isClosed: false,
              workingHours: wh,
              slots: [],
              totalOrders: 0,
              unslottedOrders: 0,
            ));
          }
        }
      }

      cursor = cursor.add(const Duration(days: 1));
    }

    return result;
  }
}

// ── Picker result ─────────────────────────────────────────────────────────────

/// Returned by [showSlotPickerSheet] when the user confirms a selection.
///
/// [dateTime] is always set — it is the slot's start time on the chosen day.
/// [timeTo] is always set — it is the slot's end time string (e.g. "09:00").
///   Previously this was derived from [slot?.timeTo], which left it empty
///   for fully-free windows.  FIX: [timeTo] now comes from [DisplaySlot]
///   directly so it is always populated regardless of availability state.
/// [slot] is non-null only when the chosen window has a booked [SlotModel]
///   attached (partial capacity). It is null for fully free windows.
class SlotPickerResult {
  final DateTime dateTime;

  /// FIX: Always populated — sourced from DisplaySlot.timeTo, not slot?.timeTo.
  final String timeTo;

  final SlotModel? slot;

  const SlotPickerResult({
    required this.dateTime,
    required this.timeTo,
    this.slot,
  });
}

// ── Display helpers ───────────────────────────────────────────────────────────

enum SlotAvailability {
  /// No booking exists for this window — completely free.
  free,

  /// Slot has orders but is not yet full.
  partial,

  /// Slot is at capacity — cannot be selected.
  full,
}

/// A normalised row displayed in the slot picker.
///
/// Rows are always generated from the supplier's working hours.  A row's
/// [source] is non-null only when the API returned a booking for that window.
class DisplaySlot {
  /// Null for windows that have no bookings yet (fully free).
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

  /// Generates display rows for [day] by expanding its working-hour windows
  /// into equal-width slots of [slotDurationMinutes].
  ///
  /// For each generated window the API-returned [SlotModel] (if any) provides
  /// the capacity state.  A window absent from the API response is completely
  /// free — the server only sends back slots that already have orders.
  ///
  /// FIX: When [filterPastSlots] is true (default) and [day.isToday] is true,
  /// any window whose start time has already passed is excluded.  This prevents
  /// users from selecting e.g. an 08:00 slot at 9 PM.
  static List<DisplaySlot> forDay(
      DaySlotModel day, {
        int slotDurationMinutes = 60,
        bool filterPastSlots = true,
      }) {
    final result = <DisplaySlot>[];
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    for (final wh in day.workingHours) {
      int cursor = _timeToMinutes(wh.open);
      final end = _timeToMinutes(wh.close);

      // If the working hour window is itself a single large block
      // (like 08:00–22:00), treat the whole window as one slot row
      // rather than chopping it into slotDurationMinutes chunks.
      final windowDuration = end - cursor;
      final effectiveDuration =
      windowDuration <= slotDurationMinutes ? windowDuration : slotDurationMinutes;

      while (cursor + effectiveDuration <= end) {
        if (filterPastSlots && day.isToday && cursor + effectiveDuration <= nowMinutes) {
          cursor += effectiveDuration;
          continue;
        }

        final from = _minutesToTime(cursor);
        final to = _minutesToTime(cursor + effectiveDuration);

        // Match booked slot by overlap, not exact string match
        final SlotModel? bookedSlot = day.slots.cast<SlotModel?>().firstWhere(
              (s) =>
          _timeToMinutes(s!.timeFrom) < cursor + effectiveDuration &&
              _timeToMinutes(s.timeTo) > cursor,
          orElse: () => null,
        );

        final availability = bookedSlot == null
            ? SlotAvailability.free
            : bookedSlot.isFull
            ? SlotAvailability.full
            : SlotAvailability.partial;

        result.add(DisplaySlot(
          source: bookedSlot,
          timeFrom: bookedSlot?.timeFrom ?? from,
          timeTo: bookedSlot?.timeTo ?? to,
          availability: availability,
        ));

        cursor += effectiveDuration;
      }
    }

    return result;
  }
}

// ── Time helpers ──────────────────────────────────────────────────────────────

int _timeToMinutes(String time) {
  final parts = time.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String _minutesToTime(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool _isToday(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

/// FIX: Returns a safe fallback string instead of throwing on an unexpected
/// weekday value (was using `!` which would crash on bad API data).
String _weekdayName(int dow) => const {
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
}[dow] ?? 'Day $dow';