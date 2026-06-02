import 'package:flutter/material.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';

import '../../../core/utils/time_format.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/slot_model.dart';
import '../data/repo/slot_repo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DeliveryWindowPickerSheet
//
// Flow:
//   1. User picks a delivery date from the horizontal date chip strip.
//   2. Sheet fetches /orders/cart/delivery-slots?date=<picked>.
//   3. Each returned slot window (e.g. 10:00–18:00) is expanded into
//      individual selectable hour chips (10:00, 11:00, … 17:00).
//   4. User taps one hour chip → scheduleAt is set to that date+hour.
//   5. Confirm returns DeliveryWindowPickerResult.
// ─────────────────────────────────────────────────────────────────────────────

// ── Result ────────────────────────────────────────────────────────────────────

class DeliveryWindowPickerResult {
  /// The exact DateTime to send as order_schedule_at (local time, at the
  /// selected hour, minute 0).
  final DateTime scheduleAt;

  /// The parent slot window the selected hour belongs to (for capacity info).
  final CartDeliverySlot slot;

  /// The calendar date the user picked.
  final DateTime date;

  const DeliveryWindowPickerResult({
    required this.scheduleAt,
    required this.slot,
    required this.date,
  });
}

// ── Public entry point ────────────────────────────────────────────────────────

Future<DeliveryWindowPickerResult?> showDeliveryWindowPicker({
  required BuildContext context,
  required List<DateTime> deliveryDates,
}) {
  return showModalBottomSheet<DeliveryWindowPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DeliveryWindowPickerSheet(deliveryDates: deliveryDates),
  );
}

// ── Internal time-option (30-min granularity) ────────────────────────────────

/// A single selectable 30-minute slot within a [CartDeliverySlot] window.
class _HourOption {
  final CartDeliverySlot slot; // parent window (carries remaining count)
  final int hour;              // 10, 10, 11, 11 …
  final int minute;            // 0 or 30

  const _HourOption({required this.slot, required this.hour, required this.minute});

  /// Raw "HH:mm" string (used for scheduling logic).
  String get raw =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// 12-hour display label, e.g. "10:00 AM" / "10:00 ص".
  String label({bool isArabic = false}) => format12h(raw, isArabic: isArabic);

  /// Builds the exact schedule DateTime for [date].
  DateTime toScheduledAt(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  bool get isAvailable => slot.isAvailable; // remaining > 0
}

/// Expands slot windows into 30-minute options, exclusive of [timeTo].
/// e.g. slot 10:00–15:00 → 10:00 10:30 11:00 … 14:00 14:30
List<_HourOption> _expandToHours(List<CartDeliverySlot> slots) {
  final result = <_HourOption>[];
  for (final slot in slots) {
    final fp = slot.timeFrom.split(':');
    final tp = slot.timeTo.split(':');
    int cursor = int.parse(fp[0]) * 60 + int.parse(fp[1]);
    final end  = int.parse(tp[0]) * 60 + int.parse(tp[1]);
    while (cursor < end) {
      result.add(_HourOption(
        slot: slot,
        hour: cursor ~/ 60,
        minute: cursor % 60,
      ));
      cursor += 30;
    }
  }
  return result;
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class _DeliveryWindowPickerSheet extends StatefulWidget {
  final List<DateTime> deliveryDates;

  const _DeliveryWindowPickerSheet({required this.deliveryDates});

  @override
  State<_DeliveryWindowPickerSheet> createState() =>
      _DeliveryWindowPickerSheetState();
}

class _DeliveryWindowPickerSheetState
    extends State<_DeliveryWindowPickerSheet> {
  final _repo = CartDeliverySlotsRepository();

  late DateTime _selectedDate;
  _HourOption? _selectedOption;
  Future<CartDeliverySlotsResponse>? _slotsFuture;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.deliveryDates.first;
    _fetchSlots(_selectedDate);
  }

  void _fetchSlots(DateTime date) {
    setState(() {
      _selectedOption = null;
      _slotsFuture = _repo.fetchSlots(date);
    });
  }

  void _selectDate(DateTime date) {
    if (date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day) {
      return;
    }
    _selectedDate = date;
    _fetchSlots(date);
  }

  DeliveryWindowPickerResult? _buildResult() {
    if (_selectedOption == null) return null;
    return DeliveryWindowPickerResult(
      scheduleAt: _selectedOption!.toScheduledAt(_selectedDate),
      slot: _selectedOption!.slot,
      date: _selectedDate,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.80;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          Flexible(child: _buildBody()),
          _buildConfirmButton(bottomPad),
        ],
      ),
    );
  }

  Widget _buildHandle() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded,
              size: 20, color: AppColors.kPrimaryColor),
          const SizedBox(width: 8),
          Text(
            l10n.chooseDeliveryDateTime,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Date strip ───────────────────────────────────────────────────────
        _DateChipsRow(
          dates: widget.deliveryDates,
          selectedDate: _selectedDate,
          onDateSelected: _selectDate,
        ),

        const Divider(height: 1),

        // ── Hour grid ────────────────────────────────────────────────────────
        Flexible(
          child: FutureBuilder<CartDeliverySlotsResponse>(
            future: _slotsFuture,
            builder: (context, snap) {
              // Loading
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              // Error
              if (snap.hasError) {
                final l10n = AppLocalizations.of(context)!;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        l10n.couldNotLoadTimeSlots,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _fetchSlots(_selectedDate),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(l10n.retry),
                      ),
                    ],
                  ),
                );
              }

              final data = snap.data!;
              final hours = _expandToHours(data.slots);

              // No hours (all slots full or empty)
              if (hours.isEmpty) {
                final l10n = AppLocalizations.of(context)!;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_busy_rounded,
                          size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noDeliveryTimesForDate,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Window range label(s)
                    ...data.slots.map((s) => _WindowRangeLabel(slot: s)),
                    const SizedBox(height: 16),

                    // Hour chips grid
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: hours.map((opt) {
                        final isSelected = _selectedOption?.hour == opt.hour &&
                            _selectedOption?.minute == opt.minute &&
                            _selectedOption?.slot == opt.slot;
                        return _HourChip(
                          option: opt,
                          isSelected: isSelected,
                          onTap: opt.isAvailable
                              ? () => setState(() => _selectedOption = opt)
                              : null,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton(double bottomPad) {
    final result = _buildResult();
    final l10n     = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final label = result == null
        ? l10n.selectATime
        : l10n.confirmAtHour(_selectedOption!.label(isArabic: isArabic));

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomPad),
      child: FilledButton(
        onPressed: result == null ? null : () => Navigator.pop(context, result),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: AppColors.kPrimaryColor,
          disabledBackgroundColor: Colors.grey.shade200,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Window range label ────────────────────────────────────────────────────────

class _WindowRangeLabel extends StatelessWidget {
  final CartDeliverySlot slot;
  const _WindowRangeLabel({required this.slot});

  @override
  Widget build(BuildContext context) {
    final l10n     = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final rangeLabel = format12hRange(
      slot.timeFrom, slot.timeTo,
      isArabic: isArabic,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 5),
          Text(
            l10n.deliveryWindowRange(rangeLabel),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (slot.remaining <= 5) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                l10n.spotsLeft(slot.remaining),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Hour chip ─────────────────────────────────────────────────────────────────

class _HourChip extends StatelessWidget {
  final _HourOption option;
  final bool isSelected;
  final VoidCallback? onTap;

  const _HourChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent   = AppColors.kPrimaryColor;
    final isFull   = !option.isAvailable;

    final bgColor = isFull
        ? Colors.grey.shade100
        : isSelected
            ? accent
            : Colors.white;

    final textColor = isFull
        ? Colors.grey.shade400
        : isSelected
            ? Colors.white
            : Colors.grey.shade800;

    final borderColor = isFull
        ? Colors.grey.shade200
        : isSelected
            ? accent
            : Colors.grey.shade300;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 72,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: accent.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              option.label(
                isArabic: Localizations.localeOf(context).languageCode == 'ar',
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (isFull)
              Text(
                AppLocalizations.of(context)!.slotFull,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Date chip strip ───────────────────────────────────────────────────────────

class _DateChipsRow extends StatelessWidget {
  final List<DateTime> dates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _DateChipsRow({
    required this.dates,
    required this.selectedDate,
    required this.onDateSelected,
  });

  static const _monthAbbr = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _dayAbbr = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.kPrimaryColor;
    return SizedBox(
      height: 85,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final date = dates[i];
          final isSelected = date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;
          final jsDay = date.weekday == 7 ? 0 : date.weekday;

          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              decoration: BoxDecoration(
                color: isSelected ? accent : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? accent : Colors.grey.shade300,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayAbbr[jsDay],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    _monthAbbr[date.month],
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.white70 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
