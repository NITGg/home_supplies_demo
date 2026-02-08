// Models for Delivery Areas Feature

class Governorate {
  final int id;
  final String name;
  final String nameAr;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Governorate({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Governorate.fromJson(Map<String, dynamic> json) {
    return Governorate(
      id: json['id'] as int,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_ar': nameAr,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}

class Area {
  final int id;
  final int governorateId;
  final String name;
  final String nameAr;
  final Map<String, dynamic> boundaries;
  final DateTime createdAt;
  final DateTime updatedAt;

  Area({
    required this.id,
    required this.governorateId,
    required this.name,
    required this.nameAr,
    required this.boundaries,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      id: json['id'] as int,
      governorateId: json['governorate_id'] as int,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      boundaries: json['boundaries'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'governorate_id': governorateId,
      'name': name,
      'name_ar': nameAr,
      'boundaries': boundaries,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class SelectedArea {
  final int id;
  final int courierId;
  final int areaId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final Area area;

  SelectedArea({
    required this.id,
    required this.courierId,
    required this.areaId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.area,
  });

  factory SelectedArea.fromJson(Map<String, dynamic> json) {
    return SelectedArea(
      id: json['id'] as int,
      courierId: json['courier_id'] as int,
      areaId: json['area_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      area: Area.fromJson(json['area'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courier_id': courierId,
      'area_id': areaId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'area': area.toJson(),
    };
  }
}

class AreaSelectionRequest {
  final int governorateId;
  final int areaId;

  AreaSelectionRequest({
    required this.governorateId,
    required this.areaId,
  });

  Map<String, dynamic> toJson() {
    return {
      'governorate_id': governorateId,
      'area_id': areaId,
    };
  }
}