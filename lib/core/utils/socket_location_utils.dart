import 'package:tawreedat_courier/core/utils/logger.dart';
import 'package:geolocator/geolocator.dart';

abstract final class LocationUtils {
  /// Returns the current position, or null if permission is denied / error.
  static Future<Position?> getCurrentPosition() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        dLog('⚠️ [LocationUtils] Permission denied');
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      dLog('⚠️ [LocationUtils] Failed to get position: $e');
      return null;
    }
  }
}