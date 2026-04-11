class CourierUser {
  final int id;
  final String fullName;
  final String phone;
  final String personalPhoto;

  CourierUser({
    required this.id,
    required this.fullName,
    required this.phone,
    this.personalPhoto = '',
  });

  factory CourierUser.fromJson(Map<String, dynamic> json) {
    return CourierUser(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      personalPhoto: (json['personal_photo'] ?? '') as String,
    );
  }
}

class CourierInfo {
  final int id;
  final num courierRate;
  final String courierVehiclePlate;
  final CourierUser user;

  CourierInfo({
    required this.id,
    required this.user,
    required this.courierRate,
    required this.courierVehiclePlate,
  });

  factory CourierInfo.fromJson(Map<String, dynamic> json) {
    return CourierInfo(
      id: json['id'] as int,
      courierRate: num.tryParse(json['avg_rating']?.toString() ?? '0') ?? 0,
      courierVehiclePlate: json['vehicle_plate'] as String,
      user: CourierUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class VehicleInfo {
  final int id;
  final String name;
  final String nameAr;
  final String icon;

  VehicleInfo({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.icon,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      icon: json['icon'] as String,
    );
  }
}

class Proposal {
  final int id;
  final int orderId;
  final int courierId;
  final String totalFee;
  final double discountFee;
  final String status;
  final double distanceToPickupM; // always in meters
  final int timeToPickup; // always in seconds
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final CourierInfo courier;
  final VehicleInfo vehicle;

  Proposal({
    required this.id,
    required this.orderId,
    required this.courierId,
    required this.totalFee,
    required this.discountFee,
    required this.status,
    required this.distanceToPickupM,
    required this.timeToPickup,
    required this.createdAt,
    this.confirmedAt,
    required this.courier,
    required this.vehicle,
  });

  factory Proposal.fromJson(Map<String, dynamic> json) {
    return Proposal(
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      courierId: json['courier_id'] as int,
      totalFee:
          ((num.tryParse(json['total_fee']?.toString() ?? '0') ?? 0) / 100)
              .toStringAsFixed(0),
      discountFee:
          (num.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0) / 100,

      // ← double now
      status: json['status'] as String,
      distanceToPickupM:
          double.tryParse(json['distance_to_pickup']?.toString() ?? '0') ?? 0,
      timeToPickup:
          int.tryParse(
            json['estimated_arrival_at_pickup']?.toString() ?? '0',
          ) ??
          0,
      createdAt: DateTime.parse(json['created_at']),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'])
          : null,
      courier: CourierInfo.fromJson(json['courier'] as Map<String, dynamic>),
      vehicle: VehicleInfo.fromJson(json['vehicle'] as Map<String, dynamic>),
    );
  }

  bool get isPending => status == 'PENDING';

  bool get isAccepted => status == 'ACCEPTED';

  bool get isRejected => status == 'REJECTED';
}

class ProposalsResponse {
  final List<Proposal> proposals;

  ProposalsResponse({required this.proposals});

  factory ProposalsResponse.fromJson(Map<String, dynamic> json) {
    return ProposalsResponse(
      proposals: (json['proposals'] as List<dynamic>)
          .map((e) => Proposal.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
