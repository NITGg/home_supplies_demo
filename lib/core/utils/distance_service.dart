
import 'api_client.dart';

/// Holds the parsed response from POST /distances
class DistanceResult {
  final double distanceMeters;
  final int durationSeconds;
  final String provider;

  const DistanceResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.provider,
  });

  factory DistanceResult.fromJson(Map<String, dynamic> json) {
    return DistanceResult(
      distanceMeters: (json['distance'] as num).toDouble(),
      durationSeconds: (json['duration'] as num).toInt(),
      provider: json['provider'] as String? ?? '',
    );
  }
}

class DistanceService {
  DistanceService._();
  static final DistanceService instance = DistanceService._();

  /// Calls POST /distances and returns the result, or throws on failure.
  Future<DistanceResult> fetchDistance({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
  }) async {
    final response = await ApiClient.instance.dio.post(
      '/distances',
      data: {
        'pickup': {'lat': pickupLat, 'lng': pickupLng},
        'delivery': {'lat': deliveryLat, 'lng': deliveryLng},
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;
    return DistanceResult.fromJson(data);
  }
}