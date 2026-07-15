class VehicleModel {
  final int id;
  final String name;
  final String nameAr;
  final String? pricePerKm;
  final String? minDeliveryFee;
  final String? maxDistancePerKm;
  final String? deliveryFeeRatio;

  final String? totalFines;

  final String? icon;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VehicleModel({
    required this.id,
    required this.name,
    required this.nameAr,
    this.pricePerKm,
    this.minDeliveryFee,
    this.maxDistancePerKm,
    this.deliveryFeeRatio,
    this.totalFines,
    this.icon,
    required this.createdAt,
    this.updatedAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as int,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      pricePerKm: json['price_per_km'] as String?,
      minDeliveryFee: json['min_delivery_fee'] as String?,
      maxDistancePerKm: json['max_distance_per_km'] as String?,
      deliveryFeeRatio: json['delivery_fee_ratio'] as String?,
      totalFines: json['total_fines'] as String?,
      icon: json['icon'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

class AvailableVehiclesResponseModel {
  final String message;
  final List<VehicleModel> vehicles;

  AvailableVehiclesResponseModel({
    required this.message,
    required this.vehicles,
  });

  factory AvailableVehiclesResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return AvailableVehiclesResponseModel(
      message: json['message'] as String,
      vehicles: (data['vehicles'] as List)
          .map((v) => VehicleModel.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}