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
  int _selectedDayIndex = 0;

  /// Id of the selected [SlotModel], or null for a free working-hour window.
  int? _selectedSlotId;

  /// For free working-hour windows (no configured slot) we track by
  /// timeFrom string instead.
  String? _selectedFreeTimeFrom;

  @override
  void initState() {
    super.initState();
    _future = widget.fetchSlots();
  }

  void _retry() => setState(() => _future = widget.fetchSlots());

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

  void _clearSelection() {
    _selectedSlotId = null;
    _selectedFreeTimeFrom = null;
  }

  /// Builds the [SlotPickerResult] to return, or null if nothing is selected.
  SlotPickerResult? _buildResult(List<DaySlotModel> openDays) {
    if (openDays.isEmpty) return null;

    final day = openDays[_selectedDayIndex.clamp(0, openDays.length - 1)];
    final rows = DisplaySlot.forDay(day);

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

    return SlotPickerResult(dateTime: dt, slot: selectedRow.source);
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

  /// Called when [onFetchError] is set and the fetch threw.
  ///
  /// Waits until the current frame finishes (so the sheet is fully mounted),
  /// pops itself, then invokes the callback — all without leaving the user
  /// staring at a broken sheet.
  void _triggerFallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss the sheet
      await widget.onFetchError!(); // open the fallback picker
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

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
          FutureBuilder<SlotStatusData>(
            future: _future,
            builder: (context, snap) => _buildConfirmButton(
              context,
              snap.data,
              bottomPad,
            ),
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

    // ── Loading ────────────────────────────────────────────────────────────
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // ── Error ──────────────────────────────────────────────────────────────
    if (snapshot.hasError) {
      // If a fallback handler is wired up, silently close and hand off.
      if (widget.onFetchError != null) {
        _triggerFallback();
        // Return a blank placeholder while the dismiss animation plays.
        return const SizedBox.shrink();
      }

      // No fallback → show the standard in-sheet error UI with retry.
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

    // Days that are open (not closed).
    final openDays = data.days.where((d) => !d.isClosed).toList();

    // ── No open days ───────────────────────────────────────────────────────
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

    final clampedDay = _selectedDayIndex.clamp(0, openDays.length - 1);
    final selectedDay = openDays[clampedDay];
    final rows = DisplaySlot.forDay(selectedDay);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Day chips ────────────────────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: openDays.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final day = openDays[i];
              final isSelected = clampedDay == i;
              final allFull = day.allSlotsFull;

              return ChoiceChip(
                label: Text(_dayLabel(day, l10n)),
                selected: isSelected,
                avatar: allFull
                    ? Icon(
                  Icons.block_rounded,
                  size: 14,
                  color: isSelected
                      ? Colors.white70
                      : Colors.grey.shade400,
                )
                    : null,
                labelStyle: TextStyle(
                  color: allFull && !isSelected ? Colors.grey.shade400 : null,
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedDayIndex = i;
                    _clearSelection();
                  });
                },
              );
            },
          ),
        ),

        const SizedBox(height: 4),

        // ── Working hours subtitle ───────────────────────────────────────
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

        // ── Slot rows ────────────────────────────────────────────────────
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
    final openDays = data.days.where((d) => !d.isClosed).toList();
    final result = _buildResult(openDays);

    final String buttonLabel;
    if (result == null) {
      buttonLabel = l10n.selectASlot;
    } else {
      final from = result.slot?.timeFrom ?? _timeLabel(result.dateTime);
      final to = result.slot?.timeTo ?? '';
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

  String _dayLabel(DaySlotModel day, AppLocalizations l10n) {
    if (day.isToday) return l10n.today;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dt = day.dateTime;
    if (dt.year == tomorrow.year &&
        dt.month == tomorrow.month &&
        dt.day == tomorrow.day) {
      return l10n.tomorrow;
    }
    return '${day.dayName.substring(0, 3)} ${dt.day}';
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
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
            // ── Time range ───────────────────────────────────────────────
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

            // ── Availability indicator ───────────────────────────────────
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