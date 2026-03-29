import 'package:geolocator/geolocator.dart';

/// Returns distance in meters between two lat/long points
double calculateDistance(
    double lat1, double lon1, double lat2, double lon2) {
  return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
}