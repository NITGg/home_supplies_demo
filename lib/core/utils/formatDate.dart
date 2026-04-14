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
