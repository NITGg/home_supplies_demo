import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/location_service.dart';

// Location States
abstract class LocationState {
  const LocationState();
}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class LocationLoaded extends LocationState {
  final String latitude;
  final String longitude;

  const LocationLoaded({
    required this.latitude,
    required this.longitude,
  });
}

class LocationError extends LocationState {
  final String message;

  const LocationError(this.message);
}

// Location Cubit
class LocationCubit extends Cubit<LocationState> {
  final LocationService _locationService;

  LocationCubit({LocationService? locationService})
      : _locationService = locationService ?? LocationService.instance,
        super(LocationInitial());

  Future<void> getCurrentLocation() async {
    emit(LocationLoading());
    try {
      final position = await _locationService.getCurrentLocation();

      if (position != null) {
        emit(LocationLoaded(
          latitude: position.latitude.toString(),
          longitude: position.longitude.toString(),
        ));
      } else {
        emit(const LocationError('Unable to get current location'));
      }
    } catch (e) {
      emit(LocationError(e.toString()));
    }
  }

  Future<bool> requestLocationPermission() async {
    return await _locationService.requestLocationPermission();
  }

  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }
}