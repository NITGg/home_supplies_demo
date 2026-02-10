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
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  String getLocalizedName(bool isArabic) => isArabic ? nameAr : name;
}

class Governorate {
  final int id;
  final String name;
  final String nameAr;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<Area> areas;

  Governorate({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.areas,
  });

  factory Governorate.fromJson(Map<String, dynamic> json) {
    return Governorate(
      id: json['id'] as int,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      deletedAt:
      json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
      areas: json['areas'] != null
          ? (json['areas'] as List<dynamic>)
          .map((e) => Area.fromJson(e as Map<String, dynamic>))
          .toList()
          : [],
    );
  }

  String getLocalizedName(bool isArabic) => isArabic ? nameAr : name;
}

class GovernoratesResponse {
  final List<Governorate> governorates;
  final int totalCount;
  final int totalPages;

  GovernoratesResponse({
    required this.governorates,
    required this.totalCount,
    required this.totalPages,
  });

  factory GovernoratesResponse.fromJson(Map<String, dynamic> json) {
    return GovernoratesResponse(
      governorates: (json['governorates'] as List<dynamic>)
          .map((e) => Governorate.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  // Get all areas flattened from all governorates
  List<Area> get allAreas {
    return governorates.expand((gov) => gov.areas).toList();
  }

  // Find area by ID
  Area? findAreaById(int areaId) {
    for (var gov in governorates) {
      for (var area in gov.areas) {
        if (area.id == areaId) {
          return area;
        }
      }
    }
    return null;
  }

  // Get governorate for a specific area
  Governorate? getGovernorateForArea(int areaId) {
    for (var gov in governorates) {
      if (gov.areas.any((area) => area.id == areaId)) {
        return gov;
      }
    }
    return null;
  }
}