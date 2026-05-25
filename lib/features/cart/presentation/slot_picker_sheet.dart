import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../data/models/slot_model.dart';

/// Opens the slot picker as a modal bottom sheet.
///
/// Returns a [SlotPickerResult] when the user confirms, or null when they
/// dismiss without selecting.
///
/// [onFetchError] is invoked (after the sheet has dismissed itself) when the
/// initial slot fetch throws. Pass [_pickScheduleDateTimeFallback] here to
/// seamlessly fall back to the free date/time picker without showing an error
/// inside the sheet.
Future<SlotPickerResult?> showSlotPickerSheet({
  required BuildContext context,
  required Future<SlotStatusData> Function() fetchSlots,
  DateTime? initialSelection,
  SlotModel? initialSlot,
  Future<void> Function()? onFetchError,
}) {
  return showModalBottomSheet<SlotPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SlotPickerSheet(
      fetchSlots: fetchSlots,
      initialSelection: initialSelection,
      initialSlot: initialSlot,
      onFetchError: onFetchError,
    ),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _SlotPickerSheet extends StatefulWidget {
  final Future<SlotStatusData> Function() fetchSlots;
  final DateTime? initialSelection;
  final SlotModel? initialSlot;

  /// Optional. When provided and the slot fetch throws, the sheet dismisses
  /// itself and calls this callback so the caller can show an alternative UI
  /// (e.g. a free date/time picker).
  final Future<void> Function()? onFetchError;

  const _SlotPickerSheet({
    required this.fetchSlots,
    this.initialSelection,
    this.initialSlot,
    this.onFetchError,
  });

  @override
  State<_SlotPickerSheet> createState() => _SlotPickerSheetState();
}

class _SlotPickerSheetState extends State<_SlotPickerSheet> {
  late Future<SlotStatusData> _future;

  /// The currently selected date string ("2026-05-25"), or null.
  String? _selectedDate;

  /// Id of the selected [SlotModel] (partial-capacity window), or null.
  int? _selectedSlotId;

  /// For fully-free windows (no booking yet) we track by timeFrom string.
  String? _selectedFreeTimeFrom;

  // ── FIX: Cache open-days to avoid calling daysInRange() twice per rebuild
  // with slightly different DateTime.now() values (once in _buildContent,
  // once in _buildConfirmButton).  Reset whenever the data changes.
  SlotStatusData? _cachedData;
  List<DaySlotModel>? _cachedOpenDays;
  int? _cachedSlotDuration;

  @override
  void initState() {
    super.initState();
    _future = widget.fetchSlots();
  }

  void _retry() => setState(() {
    _future = widget.fetchSlots();
    // Clear the cache so the new fetch result is processed fresh.
    _cachedData = null;
    _cachedOpenDays = null;
    _cachedSlotDuration = null;
  });

  /// FIX: Single source of truth for open days and slot duration.
  /// Computed once per [SlotStatusData] instance, then reused.
  ({List<DaySlotModel> openDays, int slotDuration}) _resolveData(
      SlotStatusData data) {
    if (_cachedData == data &&
        _cachedOpenDays != null &&
        _cachedSlotDuration != null) {
      return (openDays: _cachedOpenDays!, slotDuration: _cachedSlotDuration!);
    }
    final now = DateTime.now();
    _cachedData = data;
    _cachedSlotDuration = data.inferredSlotDurationMinutes;
    _cachedOpenDays = data.daysInRange(
      from: now,
      to: now.add(const Duration(days: 13)), // 2-week window
    );
    return (openDays: _cachedOpenDays!, slotDuration: _cachedSlotDuration!);
  }

  // ── Selection helpers ──────────────────────────────────────────────────────

  bool _isRowSelected(DisplaySlot row) {
    if (row.source != null) return _selectedSlotId == row.source!.id;
    return _selectedFreeTimeFrom == row.timeFrom;
  }

  void _selectRow(DisplaySlot row) {
    setState(() {
      if (row.source != null) {
        _selectedSlotId = row.source!.id;
        _selectedFreeTimeFrom = null;
      } else {
        _selectedFreeTimeFrom = row.timeFrom;
        _selectedSlotId = null;
      }
    });
  }

  void _clearSlotSelection() {
    _selectedSlotId = null;
    _selectedFreeTimeFrom = null;
  }

  /// Builds the [SlotPickerResult] to return, or null if nothing is selected.
  ///
  /// FIX: [SlotPickerResult.timeTo] is now sourced from [DisplaySlot.timeTo]
  /// so it is always populated — previously it was `slot?.timeTo ?? ''` which
  /// left it as an empty string for fully-free windows.
  SlotPickerResult? _buildResult(
      List<DaySlotModel> openDays,
      int slotDurationMinutes,
      ) {
    if (_selectedDate == null) return null;

    DaySlotModel? day;
    for (final d in openDays) {
      if (d.date == _selectedDate) {
        day = d;
        break;
      }
    }
    if (day == null) return null;

    final rows =
    DisplaySlot.forDay(day, slotDurationMinutes: slotDurationMinutes);

    DisplaySlot? selectedRow;
    for (final row in rows) {
      if (_isRowSelected(row)) {
        selectedRow = row;
        break;
      }
    }

    if (selectedRow == null) return null;

    final dt = selectedRow.source != null
        ? selectedRow.source!.toDateTime(day.dateTime)
        : _freeWindowDateTime(day.dateTime, selectedRow.timeFrom);

    return SlotPickerResult(
      dateTime: dt,
      timeTo: selectedRow.timeTo, // FIX: always from DisplaySlot, never empty
      slot: selectedRow.source,
    );
  }

  DateTime _freeWindowDateTime(DateTime date, String timeFrom) {
    final parts = timeFrom.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  // ── Fallback: dismiss sheet then open the free picker ─────────────────────

  void _triggerFallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onFetchError!();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

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
          _buildHeader(theme, context),
          Flexible(
            child: FutureBuilder<SlotStatusData>(
              future: _future,
              builder: _buildContent,
            ),
          ),
          // FIX: Share the same FutureBuilder result instead of creating a
          // second one that races with a fresh DateTime.now() call.
          FutureBuilder<SlotStatusData>(
            future: _future,
            builder: (context, snap) =>
                _buildConfirmButton(context, snap.data, bottomPad),
          ),
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

  Widget _buildHeader(ThemeData theme, BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    child: Row(
      children: [
        Text(
          AppLocalizations.of(context)!.pickDeliverySlot,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  Widget _buildContent(
      BuildContext context,
      AsyncSnapshot<SlotStatusData> snapshot,
      ) {
    final l10n = AppLocalizations.of(context)!;

    // ── Loading ──────────────────────────────────────────────────────────────
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // ── Error ────────────────────────────────────────────────────────────────
    if (snapshot.hasError) {
      if (widget.onFetchError != null) {
        _triggerFallback();
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              l10n.couldNotLoadSlots,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final data = snapshot.data!;

    // FIX: Use cached resolver — single DateTime.now() snapshot for this build.
    final (:openDays, :slotDuration) = _resolveData(data);
    final openDateSet = {for (final d in openDays) d.date};

    // ── No open days ──────────────────────────────────────────────────────────
    if (openDays.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              l10n.noOpenDaysInPeriod,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Initialise selection to the first open day when nothing is selected yet.
    if (_selectedDate == null || !openDateSet.contains(_selectedDate)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            (_selectedDate == null || !openDateSet.contains(_selectedDate))) {
          setState(() => _selectedDate = openDays.first.date);
        }
      });
    }

    final selectedDay = openDays.firstWhere(
          (d) => d.date == _selectedDate,
      orElse: () => openDays.first,
    );

    // FIX: Past-slot filtering is now handled inside DisplaySlot.forDay via
    // the filterPastSlots flag (enabled by default, uses day.isToday).
    final rows = DisplaySlot.forDay(
      selectedDay,
      slotDurationMinutes: slotDuration,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 2-week calendar grid ───────────────────────────────────────────
        _CalendarGrid(
          openDays: openDays,
          selectedDate: _selectedDate,
          slotDurationMinutes: slotDuration,
          onDateSelected: (date) {
            setState(() {
              _selectedDate = date;
              _clearSlotSelection();
            });
          },
        ),

        const SizedBox(height: 4),

        // ── Working hours subtitle ─────────────────────────────────────────
        if (selectedDay.workingHours.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 5),
                Text(
                  l10n.openHours(
                    selectedDay.workingHours
                        .map((w) => '${w.open}–${w.close}')
                        .join(', '),
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // ── Slot rows ──────────────────────────────────────────────────────
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Text(
              l10n.noSlotsConfiguredForDay,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final row = rows[i];
                return _SlotCard(
                  row: row,
                  isSelected: _isRowSelected(row),
                  onTap: row.isSelectable ? () => _selectRow(row) : null,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildConfirmButton(
      BuildContext context,
      SlotStatusData? data,
      double bottomPad,
      ) {
    if (data == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    // FIX: Reuse the cached open days — no second DateTime.now() call.
    final (:openDays, :slotDuration) = _resolveData(data);
    final result = _buildResult(openDays, slotDuration);

    final String buttonLabel;
    if (result == null) {
      buttonLabel = l10n.selectASlot;
    } else {
      // FIX: result.timeTo is now always populated (sourced from DisplaySlot),
      // so the confirm label is always complete for both free and partial slots.
      final from = result.slot?.timeFrom ?? _timeLabel(result.dateTime);
      final to = result.timeTo;
      buttonLabel = l10n.confirmSlotTime(from, to);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottomPad),
      child: FilledButton(
        onPressed: result == null ? null : () => Navigator.pop(context, result),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          buttonLabel,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Formatting ─────────────────────────────────────────────────────────────

  String _timeLabel(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

// ── Calendar grid ─────────────────────────────────────────────────────────────

/// A static 2-week (14-day) calendar grid that shows Mon–Sun column headers.
///
/// Only dates present in [openDays] are tappable; the rest are rendered as
/// dimmed/disabled cells.  The grid always starts from today and shows exactly
/// 14 days laid out in complete Mon–Sun rows, padding with disabled cells at
/// the start and end as needed.
class _CalendarGrid extends StatelessWidget {
  final List<DaySlotModel> openDays;
  final String? selectedDate;
  final int slotDurationMinutes;
  final ValueChanged<String> onDateSelected;

  const _CalendarGrid({
    required this.openDays,
    required this.selectedDate,
    required this.slotDurationMinutes,
    required this.onDateSelected,
  });

  static const _headers = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    // Build a date-string → DaySlotModel map for quick lookup.
    final openMap = <String, DaySlotModel>{
      for (final d in openDays) d.date: d,
    };

    // Determine the calendar grid start: the Monday on or before today.
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    // DateTime.weekday: 1=Mon … 7=Sun
    final gridStart = todayDate.subtract(Duration(days: todayDate.weekday - 1));

    // We always render exactly 4 rows (4 × 7 = 28 cells), anchored so that
    // today's week is the first row and we show 2 full weeks from today.
    // To keep it simple: 2 complete weeks = 14 cells, padded to full rows.
    // Rows needed: ceil((leadingBlanks + 14) / 7).
    final leadingBlanks = todayDate.weekday - 1; // days before today in row 0
    final totalCells = leadingBlanks + 14;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Day-of-week headers ────────────────────────────────────────
          Row(
            children: _headers
                .map(
                  (h) => Expanded(
                child: Center(
                  child: Text(
                    h,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            )
                .toList(),
          ),
          const SizedBox(height: 4),

          // ── Date rows ──────────────────────────────────────────────────
          for (int row = 0; row < rows; row++)
            Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final cellDate = gridStart.add(Duration(days: cellIndex));
                final dateStr = _fmt(cellDate);

                final isBeforeToday = cellDate.isBefore(todayDate);
                final dayModel = openMap[dateStr];
                final isOpen = dayModel != null;
                final isDisabled = isBeforeToday || !isOpen;
                final isSelected = dateStr == selectedDate;
                final isToday = cellDate.isAtSameMomentAs(todayDate);
                final allFull =
                isOpen ? dayModel!.allSlotsFull(slotDurationMinutes) : false;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _CalendarCell(
                      day: cellDate.day,
                      isDisabled: isDisabled,
                      isSelected: isSelected,
                      isToday: isToday,
                      allFull: allFull,
                      accent: accent,
                      onTap: isDisabled
                          ? null
                          : () => onDateSelected(dateStr),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Calendar cell ─────────────────────────────────────────────────────────────

class _CalendarCell extends StatelessWidget {
  final int day;
  final bool isDisabled;
  final bool isSelected;
  final bool isToday;
  final bool allFull;
  final Color accent;
  final VoidCallback? onTap;

  const _CalendarCell({
    required this.day,
    required this.isDisabled,
    required this.isSelected,
    required this.isToday,
    required this.allFull,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final BoxBorder? border;

    if (isSelected) {
      bgColor = accent;
      textColor = Colors.white;
      border = null;
    } else if (isToday && !isDisabled) {
      bgColor = accent.withOpacity(0.10);
      textColor = accent;
      border = Border.all(color: accent.withOpacity(0.4));
    } else if (isDisabled) {
      bgColor = Colors.transparent;
      textColor = Colors.grey.shade300;
      border = null;
    } else if (allFull) {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade400;
      border = Border.all(color: Colors.grey.shade200);
    } else {
      bgColor = Colors.transparent;
      textColor = Colors.grey.shade800;
      border = Border.all(color: Colors.grey.shade200);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected || isToday
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: textColor,
              ),
            ),
            // Full-capacity dot at the bottom of the cell
            if (allFull && !isSelected)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.red.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Slot card ─────────────────────────────────────────────────────────────────

class _SlotCard extends StatelessWidget {
  final DisplaySlot row;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SlotCard({
    required this.row,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accent = Theme.of(context).colorScheme.primary;
    final isFull = row.availability == SlotAvailability.full;

    final borderColor = isFull
        ? Colors.grey.shade200
        : isSelected
        ? accent
        : Colors.grey.shade300;

    final bgColor = isFull
        ? Colors.grey.shade50
        : isSelected
        ? accent.withOpacity(0.06)
        : Colors.white;

    final timeColor = isFull
        ? Colors.grey.shade400
        : isSelected
        ? accent
        : Colors.grey.shade800;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // ── Time range ─────────────────────────────────────────────────
            Icon(Icons.access_time_rounded, size: 18, color: timeColor),
            const SizedBox(width: 10),
            Text(
              '${row.timeFrom} – ${row.timeTo}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: timeColor,
              ),
            ),

            const Spacer(),

            // ── Availability indicator ─────────────────────────────────────
            _buildTrailing(accent, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailing(Color accent, AppLocalizations l10n) {
    return switch (row.availability) {
      SlotAvailability.full => _badge(
        l10n.slotFull,
        Colors.red.shade50,
        Colors.red.shade400,
      ),
      SlotAvailability.free => _badge(
        l10n.slotAvailable,
        Colors.green.shade50,
        Colors.green.shade600,
      ),
      SlotAvailability.partial => _capacityBar(accent),
    };
  }

  Widget _capacityBar(Color accent) {
    final ratio = row.source?.fillRatio ?? 0.0;
    final barColor =
    ratio > 0.8 ? Colors.orange.shade400 : Colors.green.shade400;
    final src = row.source!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${src.currentOrders}/${src.maxOrders}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 64,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: fg,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}