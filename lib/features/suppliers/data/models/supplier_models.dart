import 'dart:convert';

import 'package:tawreedat_go/l10n/manager/locale_cubit.dart';

/// Lightweight supplier user info embedded in every supplier response.
class SupplierUserModel {
  final int id;
  final String fullName;
  final String phone;
  final String? email;
  final String? personalPhoto;

  const SupplierUserModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.personalPhoto,
  });

  factory SupplierUserModel.fromJson(Map<String, dynamic> json) {
    return SupplierUserModel(
      id: json['id'] as int,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      personalPhoto: json['personal_photo'] as String?,
    );
  }
}

// ── Working hours ─────────────────────────────────────────────────────────────

/// A single open/close slot within a day, e.g. 09:00–13:00.
///
/// All display formatting is intentionally left to the widget layer so that
/// time strings can be localised (AM/PM vs 24-hour, RTL separators, etc.).
class WorkingSlot {
  final int openHour;
  final int openMinute;
  final int closeHour;
  final int closeMinute;

  const WorkingSlot({
    required this.openHour,
    required this.openMinute,
    required this.closeHour,
    required this.closeMinute,
  });

  factory WorkingSlot.fromJson(Map<String, dynamic> json) {
    final open = (json['open'] as String).split(':');
    final close = (json['close'] as String).split(':');
    return WorkingSlot(
      openHour: int.parse(open[0]),
      openMinute: int.parse(open[1]),
      closeHour: int.parse(close[0]),
      closeMinute: int.parse(close[1]),
    );
  }

  /// Whether [nowHour]:[nowMinute] (already in the supplier's local timezone)
  /// falls inside this slot.
  bool containsTime(int nowHour, int nowMinute) {
    final nowMins = nowHour * 60 + nowMinute;
    final openMins = openHour * 60 + openMinute;
    final closeMins = closeHour * 60 + closeMinute;
    return nowMins >= openMins && nowMins < closeMins;
  }

  /// Returns the number of minutes until this slot opens relative to
  /// [nowHour]:[nowMinute].  Null if the slot has already started or passed.
  int? minutesUntilOpen(int nowHour, int nowMinute) {
    final nowMins = nowHour * 60 + nowMinute;
    final openMins = openHour * 60 + openMinute;
    return openMins > nowMins ? openMins - nowMins : null;
  }
}

/// Working-hours schedule for one address, parsed from the JSON string in the
/// API response.
///
/// Day keys follow JavaScript's [Date.getDay()] convention:
///   0 = Sunday, 1 = Monday, … 6 = Saturday
class SupplierWorkingHours {
  final String timezone;
  final Map<int, _DaySchedule> days;

  const SupplierWorkingHours({
    required this.timezone,
    required this.days,
  });

  /// NEW: Parse directly from API map
  factory SupplierWorkingHours.fromMap(Map<String, dynamic> map) {
    final timezone = map['timezone'] as String? ?? 'UTC';

    final daysRaw = map['days'] as Map<String, dynamic>? ?? {};

    final days = <int, _DaySchedule>{};

    daysRaw.forEach((key, value) {
      final dayIndex = int.tryParse(key);

      if (dayIndex == null) return;

      final dayMap = value as Map<String, dynamic>;

      final isClosed = dayMap['is_closed'] as bool? ?? true;

      final slotsRaw = dayMap['slots'] as List<dynamic>? ?? [];

      final slots = slotsRaw
          .map((s) => WorkingSlot.fromJson(s as Map<String, dynamic>))
          .toList();

      days[dayIndex] = _DaySchedule(
        isClosed: isClosed,
        slots: slots,
      );
    });

    return SupplierWorkingHours(
      timezone: timezone,
      days: days,
    );
  }

  /// Optional backward compatibility
  factory SupplierWorkingHours.fromJsonString(String raw) {
    return SupplierWorkingHours.fromMap(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  SupplierStatus computeStatus([DateTime? nowUtc]) {
    final utc = nowUtc ?? DateTime.now().toUtc();

    final local = _toTimezone(utc, timezone);

    final jsDay = local.weekday % 7;

    final hour = local.hour;
    final minute = local.minute;

    final todaySchedule = days[jsDay];

    if (todaySchedule == null || todaySchedule.isClosed) {
      return SupplierStatus(
        isOpen: false,
        closingHour: null,
        closingMinute: null,
        nextOpenInfo: _findNextOpen(
          jsDay,
          hour,
          minute,
          skipToday: true,
        ),
      );
    }

    for (final slot in todaySchedule.slots) {
      if (slot.containsTime(hour, minute)) {
        return SupplierStatus(
          isOpen: true,
          closingHour: slot.closeHour,
          closingMinute: slot.closeMinute,
          nextOpenInfo: null,
        );
      }
    }

    return SupplierStatus(
      isOpen: false,
      closingHour: null,
      closingMinute: null,
      nextOpenInfo: _findNextOpen(
        jsDay,
        hour,
        minute,
        skipToday: false,
      ),
    );
  }

  NextOpenInfo? _findNextOpen(
      int jsDay,
      int nowHour,
      int nowMinute, {
        required bool skipToday,
      }) {
    for (int offset = skipToday ? 1 : 0; offset <= 7; offset++) {
      final checkDay = (jsDay + offset) % 7;

      final sched = days[checkDay];

      if (sched == null || sched.isClosed || sched.slots.isEmpty) {
        continue;
      }

      for (final slot in sched.slots) {
        if (offset == 0) {
          final mins = slot.minutesUntilOpen(nowHour, nowMinute);

          if (mins == null) continue;
        }

        return NextOpenInfo(
          jsDayIndex: checkDay,
          isToday: offset == 0,
          isTomorrow: offset == 1,
          openHour: slot.openHour,
          openMinute: slot.openMinute,
        );
      }
    }

    return null;
  }

  static DateTime _toTimezone(DateTime utc, String tz) =>
      utc.add(Duration(hours: _tzOffset(tz)));

  static int _tzOffset(String tz) {
    const map = <String, int>{
      'Africa/Cairo': 3,
      'Africa/Johannesburg': 2,
      'America/Chicago': -5,
      'America/Denver': -6,
      'America/Los_Angeles': -7,
      'America/New_York': -4,
      'Asia/Baghdad': 3,
      'Asia/Beirut': 3,
      'Asia/Dubai': 4,
      'Asia/Jerusalem': 3,
      'Asia/Karachi': 5,
      'Asia/Kolkata': 6,
      'Asia/Kuwait': 3,
      'Asia/Riyadh': 3,
      'Asia/Tokyo': 9,
      'Europe/Berlin': 2,
      'Europe/London': 1,
      'Europe/Moscow': 3,
      'Europe/Paris': 2,
      'UTC': 0,
    };

    return map[tz] ?? 0;
  }

  List<WorkingSlot> todaySlots([DateTime? nowUtc]) {
    final utc = nowUtc ?? DateTime.now().toUtc();

    final local = _toTimezone(utc, timezone);

    final jsDay = local.weekday % 7;

    final sched = days[jsDay];

    if (sched == null || sched.isClosed) {
      return [];
    }

    return sched.slots;
  }

  List<({int jsDay, bool isClosed, List<WorkingSlot> slots})> allDays() {
    return List.generate(7, (i) {
      final sched = days[i];

      return (
      jsDay: i,
      isClosed: sched?.isClosed ?? true,
      slots: sched?.slots ?? [],
      );
    });
  }

  int currentJsDay([DateTime? nowUtc]) {
    final utc = nowUtc ?? DateTime.now().toUtc();

    return _toTimezone(utc, timezone).weekday % 7;
  }

  /// True when every day of the week is open with at least one full-day slot
  /// (00:00–00:00), meaning the supplier is effectively open 24/7.
  bool get isAlwaysOpen {
    if (days.length < 7) return false;
    for (int i = 0; i < 7; i++) {
      final sched = days[i];
      if (sched == null || sched.isClosed || sched.slots.isEmpty) return false;
      final hasFullDay = sched.slots.any(
        (s) =>
            s.openHour == 0 &&
            s.openMinute == 0 &&
            s.closeHour == 23 &&
            s.closeMinute == 59,
      );
      if (!hasFullDay) return false;
    }
    return true;
  }
}

class _DaySchedule {
  final bool isClosed;
  final List<WorkingSlot> slots;
  const _DaySchedule({required this.isClosed, required this.slots});
}

/// Information about when the supplier next opens.
/// Carries raw numeric data only — all localised strings are built in the UI.
class NextOpenInfo {
  /// JS-style weekday index (0 = Sunday, 6 = Saturday).
  final int jsDayIndex;
  final bool isToday;
  final bool isTomorrow;
  final int openHour;
  final int openMinute;

  const NextOpenInfo({
    required this.jsDayIndex,
    required this.isToday,
    required this.isTomorrow,
    required this.openHour,
    required this.openMinute,
  });
}

/// Result of [SupplierWorkingHours.computeStatus].
/// All fields are raw numerics — formatting belongs in the widget layer.
class SupplierStatus {
  final bool isOpen;

  /// Closing time of the active slot (null when supplier is closed).
  final int? closingHour;
  final int? closingMinute;

  /// When the supplier next opens (null when currently open).
  final NextOpenInfo? nextOpenInfo;

  const SupplierStatus({
    required this.isOpen,
    required this.closingHour,
    required this.closingMinute,
    required this.nextOpenInfo,
  });

  /// True when closed and the next opening is NOT later today — an order
  /// placed now will be delivered on a future calendar day.
  bool get orderDeliveredTomorrow =>
      !isOpen && nextOpenInfo != null && !nextOpenInfo!.isToday;
}

// ── Address ───────────────────────────────────────────────────────────────────

class SupplierAddressModel {
  final int id;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? state;
  final String? country;
  final String? googleMapLink;
  final String? latitude;
  final String? longitude;
  final String? contactName;
  final String? contactPhone;
  final SupplierWorkingHours? workingHours;

  const SupplierAddressModel({
    required this.id,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    this.state,
    this.country,
    this.googleMapLink,
    this.latitude,
    this.longitude,
    this.contactName,
    this.contactPhone,
    this.workingHours,
  });

  factory SupplierAddressModel.fromJson(Map<String, dynamic> json) {
    SupplierWorkingHours? wh;

    final raw = json['working_hours'];

    try {
      if (raw is Map<String, dynamic>) {
        wh = SupplierWorkingHours.fromMap(raw);
      } else if (raw is String && raw.trim().isNotEmpty) {
        wh = SupplierWorkingHours.fromJsonString(raw);
      }
    } catch (_) {
      wh = null;
    }

    return SupplierAddressModel(
      id: json['id'] as int,
      addressLine1: json['address_line_1'] as String? ?? '',
      addressLine2: json['address_line_2'] as String?,
      city: json['city'] as String? ?? '',
      state: json['state'] as String?,
      country: json['country'] as String?,
      googleMapLink: json['google_map_link'] as String?,
      latitude: json['latitude'] as String?,
      longitude: json['longitude'] as String?,
      contactName: json['contact_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      workingHours: wh,
    );
  }
}

// ── Minimal category info ─────────────────────────────────────────────────────

class SupplierCategoryModel {
  final int id;
  final String name;
  final String? nameAr;
  final String? imageUrl;
  final String? iconUrl;

  const SupplierCategoryModel({
    required this.id,
    required this.name,
    this.nameAr,
    this.imageUrl,
    this.iconUrl,
  });

  factory SupplierCategoryModel.fromJson(Map<String, dynamic> json) {
    return SupplierCategoryModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      nameAr: json['name_ar'] as String?,
      imageUrl: json['image_url'] as String?,
      iconUrl: json['icon_url'] as String?,
    );
  }

  String get displayName =>
      LocaleManager.currentLocale == 'ar' ? (nameAr ?? name) : name;
}

// ── Core supplier model ───────────────────────────────────────────────────────

class SupplierModel {
  final int id;
  final bool isApproved;
  final String? synonyms;
  final SupplierUserModel user;
  final List<SupplierCategoryModel> categories;
  final List<SupplierAddressModel> addresses;
  final double avgRating;
  final double distanceKm;

  const SupplierModel({
    required this.id,
    required this.isApproved,
    this.synonyms,
    required this.user,
    this.categories = const [],
    this.addresses = const [],
    this.avgRating = 0,
    this.distanceKm = 0,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categories'] as List<dynamic>? ?? [];
    final categories = rawCats.map((e) {
      final inner = e as Map<String, dynamic>;
      final catJson = inner.containsKey('category')
          ? inner['category'] as Map<String, dynamic>
          : inner;
      return SupplierCategoryModel.fromJson(catJson);
    }).toList();

    final rawAddresses = json['addresses'] as List<dynamic>? ?? [];
    final addresses = rawAddresses
        .map((a) => SupplierAddressModel.fromJson(a as Map<String, dynamic>))
        .toList();

    return SupplierModel(
      id: json['id'] as int,
      isApproved: json['is_approved'] as bool? ?? false,
      synonyms: json['synonyms'] as String?,
      user: SupplierUserModel.fromJson(json['user'] as Map<String, dynamic>),
      categories: categories,
      addresses: addresses,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
    );
  }

  String get displayName {

    return user.fullName;
  }

  String? get photoUrl => user.personalPhoto;

  SupplierWorkingHours? get workingHours =>
      addresses.isNotEmpty ? addresses.first.workingHours : null;

  SupplierStatus? get currentStatus => workingHours?.computeStatus();
}