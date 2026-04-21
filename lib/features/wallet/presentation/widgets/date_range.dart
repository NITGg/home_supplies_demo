import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';

class DateRangeSelector extends StatefulWidget {
  final Function(String?, String?, DateRangePreset) onDateRangeChanged;
  final bool isArabic;
  final DateRangePreset selectedPreset;

  const DateRangeSelector({
    super.key,
    required this.onDateRangeChanged,
    required this.isArabic,
    this.selectedPreset = DateRangePreset.all,

  });

  @override
  State<DateRangeSelector> createState() => _DateRangeSelectorState();
}

class _DateRangeSelectorState extends State<DateRangeSelector> {
  DateTime? _startDate;
  DateTime? _endDate;
  late DateRangePreset _selectedPreset;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.selectedPreset;
  }

  @override
  void didUpdateWidget(DateRangeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPreset != widget.selectedPreset) {
      setState(() {
        _selectedPreset = widget.selectedPreset; // ← sync if parent changes it
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.date_range, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.isArabic ? 'الفترة' : 'Date Range',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Preset Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip(
                DateRangePreset.all,
                AppLocalizations.of(context)!.all,
              ),
              _buildPresetChip(
                DateRangePreset.today,
                AppLocalizations.of(context)!.today,
              ),
              _buildPresetChip(
                DateRangePreset.thisWeek,
                AppLocalizations.of(context)!.thisWeek,
              ),
              _buildPresetChip(
                DateRangePreset.thisMonth,
                AppLocalizations.of(context)!.thisMonth,
              ),
              _buildPresetChip(
                DateRangePreset.lastMonth,
                AppLocalizations.of(context)!.lastMonth,
              ),
              _buildPresetChip(
                DateRangePreset.custom,
                AppLocalizations.of(context)!.custom,
              ),
            ],
          ),

          // Custom Date Range Selector
          if (_selectedPreset == DateRangePreset.custom) ...[
            const SizedBox(height: 16),
            Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Row(
                children: [
                  Expanded(
                    child: _buildDateButton(
                      label: AppLocalizations.of(context)!.from,
                      date: _startDate,
                      onTap: () => _selectDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateButton(
                      label: AppLocalizations.of(context)!.to,
                      date: _endDate,
                      onTap: () => _selectDate(context, false),
                    ),
                  ),
                ],
              ),
            ),
            if (_startDate != null || _endDate != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _clearCustomDates,
                    icon: const Icon(Icons.clear, size: 18),
                    label: Text(
                      AppLocalizations.of(context)!.clear,
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _applyCustomDates,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      AppLocalizations.of(context)!.apply,
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPresetChip(DateRangePreset preset, String label) {
    final isSelected = _selectedPreset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPreset = preset;
          });
          _applyPreset(preset);
        }
      },
      selectedColor: Colors.orangeAccent,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF666666),
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: date != null ? Colors.orangeAccent : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? DateFormat('yyyy-MM-dd').format(date)
                  : AppLocalizations.of(context)!.selectDate,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: date != null
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFF999999),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyPreset(DateRangePreset preset) {
    final now = DateTime.now();
    String? startDate;
    String? endDate;

    switch (preset) {
      case DateRangePreset.all:
        startDate = null;
        endDate = null;
        break;

      case DateRangePreset.today:
        startDate = DateFormat('yyyy-MM-dd').format(now);
        endDate = DateFormat('yyyy-MM-dd').format(now);
        break;

      case DateRangePreset.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateFormat('yyyy-MM-dd').format(weekStart);
        endDate = DateFormat('yyyy-MM-dd').format(now);
        break;

      case DateRangePreset.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        startDate = DateFormat('yyyy-MM-dd').format(monthStart);
        endDate = DateFormat('yyyy-MM-dd').format(now);
        break;

      case DateRangePreset.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(
          now.year,
          now.month,
          0,
        ); // Last day of previous month
        startDate = DateFormat('yyyy-MM-dd').format(lastMonth);
        endDate = DateFormat('yyyy-MM-dd').format(lastMonthEnd);
        break;

      case DateRangePreset.custom:
      // Don't apply anything for custom, wait for user selection
        return;
    }

    widget.onDateRangeChanged(startDate, endDate, preset);
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.orangeAccent),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before start date, adjust it
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
          // If start date is after end date, adjust it
          if (_startDate != null && _startDate!.isAfter(picked)) {
            _startDate = picked;
          }
        }
      });
    }
  }

  void _applyCustomDates() {
    if (_startDate != null || _endDate != null) {
      final startDate = _startDate != null
          ? DateFormat('yyyy-MM-dd').format(_startDate!)
          : null;
      final endDate = _endDate != null
          ? DateFormat('yyyy-MM-dd').format(_endDate!)
          : null;
      widget.onDateRangeChanged(startDate, endDate, DateRangePreset.custom); // ← add preset
    }
  }

  void _clearCustomDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }
}

enum DateRangePreset { all, today, thisWeek, thisMonth, lastMonth, custom }
