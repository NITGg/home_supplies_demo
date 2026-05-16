import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';

String formatDate(BuildContext context, DateTime date) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 1) {
    return l10n.justNow;
  } else if (diff.inMinutes < 60) {
    return l10n.minutesAgo(diff.inMinutes);
  } else if (diff.inHours < 24) {
    return l10n.hoursAgo(diff.inHours);
  } else if (diff.inDays < 7) {
    return l10n.daysAgo(diff.inDays);
  } else {
    return DateFormat('MMM dd').format(date);
  }
}

String formatDuration(int minutes, AppLocalizations l10n) {
  if (minutes < 60) {
    return '$minutes ${l10n.min}';
  }

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  if (remainingMinutes == 0) {
    return '$hours ${l10n.hour}';
  }

  return '$hours ${l10n.hour} $remainingMinutes ${l10n.min}';
}

String formatDurationRange(int from, int to, AppLocalizations l10n) {
  // Same unit on both sides → show "10–20 min" or "1–2 hr"
  // Mixed (e.g. 50 min → 1 hr 10 min) → fall back to two full labels
  if (from < 60 && to < 60) {
    return '$from–$to ${l10n.min}';
  }

  final fromH = from ~/ 60;
  final fromM = from % 60;
  final toH   = to   ~/ 60;
  final toM   = to   % 60;

  if (fromM == 0 && toM == 0) {
    return '$fromH–$toH ${l10n.hour}';
  }

  // Mixed — just join the two full strings with an en-dash
  return '${formatDuration(from, l10n)}–${formatDuration(to, l10n)}';
}
