// import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class LocationService {
//   LocationService._();
//   static final LocationService instance = LocationService._();
//
//   Future<bool> requestLocationPermission() async {
//     final status = await Permission.location.request();
//     return status.isGranted;
//   }
//
//   Future<bool> isLocationServiceEnabled() async {
//     return await Geolocator.isLocationServiceEnabled();
//   }
//
//   Future<LocationPermission> checkPermission() async {
//     return await Geolocator.checkPermission();
//   }
//
//   Future<Position?> getCurrentLocation() async {
//     try {
//       // Check if location services are enabled
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         throw Exception('Location services are disabled. Please enable them in settings.');
//       }
//
//       // Check permissions
//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) {
//           throw Exception('Location permissions are denied');
//         }
//       }
//
//       if (permission == LocationPermission.deniedForever) {
//         throw Exception('Location permissions are permanently denied. Please enable them in settings.');
//       }
//
//       // Get current position
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//
//       return position;
//     } catch (e) {
//       rethrow;
//     }
//   }
//
//   Future<void> openLocationSettings() async {
//     await Geolocator.openLocationSettings();
//   }
//
//   Future<void> openAppSettings() async {
//     await openAppSettings();
//   }
// }