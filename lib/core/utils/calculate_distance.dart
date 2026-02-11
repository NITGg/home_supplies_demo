import 'dart:math';

/// Returns distance in meters between two lat/long points
double calculateDistance(
    double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371000; // meters
  final dLat = _degreesToRadians(lat2 - lat1);
  final dLon = _degreesToRadians(lon2 - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _degreesToRadians(double degrees) => degrees * pi / 180;
