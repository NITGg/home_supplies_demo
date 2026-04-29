// ==================== Points Rules Model ====================
class PointsRulesModel {
  final PointsRules rules;
  final PointsRules rulesAr;

  PointsRulesModel({required this.rules, required this.rulesAr});

  factory PointsRulesModel.fromJson(Map<String, dynamic> json) {
    return PointsRulesModel(
      rules: PointsRules.fromJson(json['rules']),
      rulesAr: PointsRules.fromJson(json['rules_ar']),
    );
  }

  PointsRules getLocalized(bool isArabic) => isArabic ? rulesAr : rules;
}

class PointsRules {
  final String ordersReward;
  final String pointsValue;
  final String expiration;
  final String redemption;

  PointsRules({
    required this.ordersReward,
    required this.pointsValue,
    required this.expiration,
    required this.redemption,
  });

  factory PointsRules.fromJson(Map<String, dynamic> json) {
    return PointsRules(
      ordersReward: json['orders_reward'] as String,
      pointsValue: json['points_value'] as String,
      expiration: json['expiration'] as String,
      redemption: json['redemption'] as String,
    );
  }
}

// ==================== Points Progress Model ====================
class PointsProgressModel {
  final PointsBalance balance;
  final UpcomingExpiration? upcomingExpiration;
  final PointsProgress progress;

  PointsProgressModel({
    required this.balance,
    this.upcomingExpiration,
    required this.progress,
  });

  factory PointsProgressModel.fromJson(Map<String, dynamic> json) {
    return PointsProgressModel(
      balance: PointsBalance.fromJson(json['balance']),
      upcomingExpiration: json['upcomingExpiration'] != null
          ? UpcomingExpiration.fromJson(json['upcomingExpiration'])
          : null,
      progress: PointsProgress.fromJson(json['progress']),
    );
  }
}

class PointsBalance {
  final int availablePoints;
  final double monetaryValueEgp;

  PointsBalance({
    required this.availablePoints,
    required this.monetaryValueEgp,
  });

  factory PointsBalance.fromJson(Map<String, dynamic> json) {
    return PointsBalance(
      availablePoints: (json['availablePoints'] as num).toInt(),
      monetaryValueEgp: (json['monetaryValueEgp'] as num).toDouble(),
    );
  }
}

class UpcomingExpiration {
  final int points;
  final DateTime expiresAt;

  UpcomingExpiration({required this.points, required this.expiresAt});

  factory UpcomingExpiration.fromJson(Map<String, dynamic> json) {
    return UpcomingExpiration(
      points: (json['points_expiring'] as num).toInt(), // was 'points'
      expiresAt: DateTime.parse(json['date'] as String), // was 'expires_at'
    );
  }
}

class PointsProgress {
  final OrdersBatch ordersBatch;

  PointsProgress({required this.ordersBatch});

  factory PointsProgress.fromJson(Map<String, dynamic> json) {
    return PointsProgress(
      ordersBatch: OrdersBatch.fromJson(json['ordersBatch']),
    );
  }
}

class OrdersBatch {
  final int currentOrder;
  final int requiredOrders;
  final List<dynamic> batches;

  OrdersBatch({
    required this.currentOrder,
    required this.requiredOrders,
    required this.batches,
  });

  factory OrdersBatch.fromJson(Map<String, dynamic> json) {
    return OrdersBatch(
      currentOrder: (json['current_order'] as num).toInt(),
      requiredOrders: (json['required_orders'] as num).toInt(),
      batches: json['batches'] as List<dynamic>? ?? [],
    );
  }

  double get progressPercentage => requiredOrders > 0
      ? (currentOrder / requiredOrders).clamp(0.0, 1.0)
      : 0.0;

  int get remainingOrders =>
      (requiredOrders - currentOrder).clamp(0, requiredOrders);
}
