class WalletModel {
  final Wallet wallet;
  final UserBadge badge;
  final int completedCount;
  final UserBadge? nextBadge;
  final int remainingToNext;
  final double totalFines;

  WalletModel({
    required this.wallet,
    required this.totalFines,
    required this.badge,
    required this.completedCount,
    this.nextBadge,
    required this.remainingToNext,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(

        totalFines: ((num.tryParse(json['totalFines']?.toString() ?? '0') ?? 0) / 100),
      wallet: Wallet.fromJson(json['wallet']),
      badge: UserBadge.fromJson(json['badge']),
      completedCount: json['completedCount'] ?? 0,
      nextBadge: json['nextBadge'] != null ? UserBadge.fromJson(json['nextBadge']) : null,
      remainingToNext: json['remainingToNext'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wallet': wallet.toJson(),
      'badge': badge.toJson(),
      'completedCount': completedCount,
      'nextBadge': nextBadge?.toJson(),
      'remainingToNext': remainingToNext,
    };
  }
}

class Wallet {
  final int id;
  final double balance;
  final double points;
  final String status;
  final String ownerType;
  final String? freezeReason;
  final String? frozenAt;

  Wallet({
    required this.id,
    required this.balance,
    required this.points,
    required this.status,
    required this.ownerType,
    this.freezeReason,
    this.frozenAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'],
      balance: ((num.tryParse(json['balance']?.toString() ?? '0') ?? 0) / 100)
      , points: (num.tryParse(json['points']?.toString() ?? '0') ?? 0)/1
      ,
      status: json['status'] ?? 'ACTIVE',
      ownerType: json['owner_type'] ?? 'CUSTOMER',
      freezeReason: json['freeze_reason'],
      frozenAt: json['frozen_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'balance': balance,
      'status': status,
      'owner_type': ownerType,
      'freeze_reason': freezeReason,
      'frozen_at': frozenAt,
    };
  }

  bool get isActive => status == 'ACTIVE';
  bool get isFrozen => status == 'FROZEN';
}

class UserBadge {
  final int id;
  final int roleId;
  final String name;
  final String nameAr;
  final String image;
  final String description;
  final String descriptionAr;
  final int minCount;
  final int maxCount;
  final double ratio;
  final String createdAt;
  final String updatedAt;

  UserBadge({
    required this.id,
    required this.roleId,
    required this.name,
    required this.nameAr,
    required this.image,
    required this.description,
    required this.descriptionAr,
    required this.minCount,
    required this.maxCount,
    required this.ratio,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      id: json['id'],
      roleId: json['role_id'],
      name: json['name'] ?? '',
      nameAr: json['name_ar'] ?? '',
      image: json['image'] ?? '',
      description: json['description'] ?? '',
      descriptionAr: json['description_ar'] ?? '',
      minCount: json['min_count'] ?? 0,
      maxCount: json['max_count'] ?? 0,
      ratio: (json['ratio'] ?? 0).toDouble(),
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role_id': roleId,
      'name': name,
      'name_ar': nameAr,
      'image': image,
      'description': description,
      'description_ar': descriptionAr,
      'min_count': minCount,
      'max_count': maxCount,
      'ratio': ratio,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  double get commissionRate => ratio;
}