import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../l10n/app_localizations.dart';

/// Returns distance in meters between two lat/long points
double calculateDistance(
    double lat1, double lon1, double lat2, double lon2) {
  return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
}

String distanceLabelFromString(BuildContext context, String distanceMStr) {
  final l10n = AppLocalizations.of(context)!;

  final distanceM = double.tryParse(distanceMStr);

  // fallback if parsing fails
  if (distanceM == null) return '--';

  if (distanceM >= 1000) {
    return '${(distanceM / 1000).toStringAsFixed(1)} ${l10n.km}';
  }

  return '${distanceM.toStringAsFixed(0)} ${l10n.m}';
}