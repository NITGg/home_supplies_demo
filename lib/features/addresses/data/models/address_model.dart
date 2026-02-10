class Address {
  final int? id;
  final int? customerId;
  final int areaId;
  final String addressLat;
  final String? name;
  final String addressLong;
  final bool isDefault;
  final String detailedAddress;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const Address({
    this.id,
    this.customerId,
    this.name,
    required this.areaId,
    required this.addressLat,
    required this.addressLong,
    required this.isDefault,
    required this.detailedAddress,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as int?,
      customerId: json['customer_id'] as int?,
      areaId: json['area_id'] as int,
      name: json['name'],
      isDefault: json['is_default'] == true,
      addressLat: json['address_lat'] as String,
      addressLong: json['address_long'] as String,
      detailedAddress: json['detailed_address'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      'area_id': areaId,
      if (name != null) 'name': name,
      'is_default': isDefault,
      'address_lat': addressLat,
      'address_long': addressLong,
      'detailed_address': detailedAddress,
    };
  }

  Address copyWith({
    int? id,
    int? customerId,
    int? areaId,
    String? name,
    bool? isDefault,
    String? addressLat,
    String? addressLong,
    String? detailedAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Address(
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      areaId: areaId ?? this.areaId,
      addressLat: addressLat ?? this.addressLat,
      addressLong: addressLong ?? this.addressLong,
      detailedAddress: detailedAddress ?? this.detailedAddress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  String get displayAddress {
    if (name != null && name!.isNotEmpty) {
      return '$name - $detailedAddress';
    }
    return detailedAddress;
  }

  @override
  List<Object?> get props => [
    id,
    customerId,
    name,
    isDefault,
    areaId,
    addressLat,
    addressLong,
    detailedAddress,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}

class AddressesResponse {
  final List<Address> addresses;
  final int totalAddresses;
  final int totalPages;

  AddressesResponse({
    required this.addresses,
    required this.totalAddresses,
    required this.totalPages,
  });

  factory AddressesResponse.fromJson(Map<String, dynamic> json) {
    return AddressesResponse(
      addresses: (json['addresses'] as List<dynamic>)
          .map((e) => Address.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAddresses: json['totalAddresses'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}

class AddressOperationResponse {
  final String message;
  final Address address;

  AddressOperationResponse({
    required this.message,
    required this.address,
  });

  factory AddressOperationResponse.fromJson(Map<String, dynamic> json) {
    return AddressOperationResponse(
      message: json['message'] as String,
      address: Address.fromJson(json['address'] as Map<String, dynamic>),
    );
  }
}