import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../suppliers/data/models/supplier_models.dart';

/// Drop-in working-hours banner for the main supplier.
///
/// Identical in behaviour to the private `_WorkingHoursBanner` used inside
/// `SupplierDetailScreen`, but exported so that category-detail screens and
/// any other page can reuse it without duplicating code.
///
/// Usage:
/// ```dart
/// if (state.mainSupplier?.workingHours != null)
///   MainSupplierWorkingHoursBanner(supplier: state.mainSupplier!),
/// ```
class MainSupplierWorkingHoursBanner extends StatelessWidget {
  final SupplierModel supplier;

  const MainSupplierWorkingHoursBanner({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    // Guard: only render when working-hours data is available.
    final wh = supplier.workingHours;
    final status = supplier.currentStatus;
    if (wh == null || status == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final todaySlots = wh.todaySlots();

    final isOpen = status.isOpen;
    final pillColor = isOpen
        ? const Color(0xFF1DB954)
        : theme.colorScheme.error;
    final pillBg = isOpen
        ? const Color(0xFF1DB954).withOpacity(0.12)
        : theme.colorScheme.errorContainer.withOpacity(0.45);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Main banner row ───────────────────────────────────────────────
          InkWell(
            onTap: () => _showAllHoursSheet(context, wh, theme, l10n),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SvgPicture.asset('assets/images/appbar/Go.svg', height: 20),
                  const SizedBox(width: 5),

                  // ── Open / Closed pill ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pillColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isOpen ? l10n.openNow : l10n.closed,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: pillColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ── Contextual message ────────────────────────────────────
                  Expanded(
                    child: _StatusMessage(
                      status: status,
                      todaySlots: todaySlots,
                      l10n: l10n,
                      theme: theme,
                    ),
                  ),

                  // ── Chevron ───────────────────────────────────────────────
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),

          // ── "Order delivers tomorrow" nudge ──────────────────────────────
          // Commented out: orders placed outside opening hours are now blocked
          // rather than scheduled, so this notice is no longer shown.
          // if (status.orderDeliveredTomorrow)
          //   _TomorrowNudge(status: status, theme: theme, l10n: l10n),
          Divider(color: Colors.grey.shade200, height: 1),
        ],
      ),
    );
  }

  void _showAllHoursSheet(
    BuildContext context,
    SupplierWorkingHours wh,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllHoursSheet(wh: wh, theme: theme, l10n: l10n),
    );
  }
}

// ── Helpers — time formatting ─────────────────────────────────────────────────

String _fmtTime(int hour, int minute, AppLocalizations l10n) {
  final isArabic = l10n.localeName == 'ar';
  final min = minute.toString().padLeft(2, '0');

  if (isArabic) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour < 12 ? 'صباحاً' : 'مساءً';
    return '${_toArabicNumerals('$h12:$min')} $suffix';
  } else {
    final period = hour < 12 ? 'AM' : 'PM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:$min $period';
  }
}

String _toArabicNumerals(String s) {
  const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var result = s;
  for (var i = 0; i < en.length; i++) {
    result = result.replaceAll(en[i], ar[i]);
  }
  return result;
}

String _slotRange(WorkingSlot slot, AppLocalizations l10n) {
  final open = _fmtTime(slot.openHour, slot.openMinute, l10n);
  final close = _fmtTime(slot.closeHour, slot.closeMinute, l10n);
  return '$open – $close';
}

String _dayName(int jsDayIndex, AppLocalizations l10n) {
  switch (jsDayIndex) {
    case 0:
      return l10n.daySunday;
    case 1:
      return l10n.dayMonday;
    case 2:
      return l10n.dayTuesday;
    case 3:
      return l10n.dayWednesday;
    case 4:
      return l10n.dayThursday;
    case 5:
      return l10n.dayFriday;
    case 6:
      return l10n.daySaturday;
    default:
      return '';
  }
}

// ── Status message ────────────────────────────────────────────────────────────

class _StatusMessage extends StatelessWidget {
  final SupplierStatus status;
  final List<WorkingSlot> todaySlots;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _StatusMessage({
    required this.status,
    required this.todaySlots,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final base = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (status.isOpen && status.closingHour != null) {
      return Text(
        l10n.closesAt(
          _fmtTime(status.closingHour!, status.closingMinute ?? 0, l10n),
        ),
        style: base,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final next = status.nextOpenInfo;
    if (next == null) return const SizedBox.shrink();

    final timeStr = _fmtTime(next.openHour, next.openMinute, l10n);
    if (next.isToday) return Text(l10n.opensAt(timeStr), style: base);
    if (next.isTomorrow) {
      return Text(l10n.opensTomorrowAt(timeStr), style: base);
    }
    return Text(
      l10n.opensDayAt(_dayName(next.jsDayIndex, l10n), timeStr),
      style: base,
    );
  }
}

// ── "Order delivers tomorrow" nudge ──────────────────────────────────────────

class _TomorrowNudge extends StatelessWidget {
  final SupplierStatus status;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _TomorrowNudge({
    required this.status,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final next = status.nextOpenInfo!;
    final timeStr = _fmtTime(next.openHour, next.openMinute, l10n);

    final String whenLabel;
    if (next.isTomorrow) {
      whenLabel = l10n
          .opensTomorrowAt(timeStr)
          .replaceFirst(RegExp(r'^(يفتح\s|Opens\s)', caseSensitive: false), '');
    } else {
      whenLabel = l10n
          .opensDayAt(_dayName(next.jsDayIndex, l10n), timeStr)
          .replaceFirst(RegExp(r'^(يفتح\s|Opens\s)', caseSensitive: false), '');
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 15,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              l10n.orderDeliveredTomorrowNotice(whenLabel),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full weekly hours bottom sheet ────────────────────────────────────────────

class _AllHoursSheet extends StatelessWidget {
  final SupplierWorkingHours wh;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _AllHoursSheet({
    required this.wh,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final jsToday = wh.currentJsDay();
    final allDays = wh.allDays();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.workingHours,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.grey.shade200),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: allDays.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (_, i) {
                final day = allDays[i];
                return _DayRow(
                  dayName: _dayName(day.jsDay, l10n),
                  isClosed: day.isClosed,
                  slots: day.slots,
                  isToday: day.jsDay == jsToday,
                  theme: theme,
                  l10n: l10n,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── Day row ───────────────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final String dayName;
  final bool isClosed;
  final List<WorkingSlot> slots;
  final bool isToday;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _DayRow({
    required this.dayName,
    required this.isClosed,
    required this.slots,
    required this.isToday,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final todayBg = isToday
        ? theme.colorScheme.primaryContainer.withOpacity(0.35)
        : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: todayBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isClosed || slots.isEmpty
                ? Text(
                    l10n.closed,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: slots
                        .map(
                          (s) => Text(
                            _slotRange(s, l10n),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
