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
  final int pendingBatchBalance; // 👈 points accumulated, not yet unlocked

  PointsProgressModel({
    required this.balance,
    this.upcomingExpiration,
    required this.progress,
    required this.pendingBatchBalance,
  });

  factory PointsProgressModel.fromJson(Map<String, dynamic> json) {
    final availableBatches = (json['availableBatches'] as List<dynamic>?) ?? [];
    final totalPoints = availableBatches.fold<int>(
      0,
          (sum, b) => sum + (b['balance'] as num).toInt(),
    );

    final allExpirations = (json['allExpirations'] as List<dynamic>?) ?? [];
    final pendingBatch = json['pendingBatch'] as Map<String, dynamic>?;

    return PointsProgressModel(
      balance: PointsBalance(
        availablePoints: totalPoints,
        monetaryValueEgp: 0,
      ),
      upcomingExpiration: allExpirations.isNotEmpty
          ? UpcomingExpiration.fromJson(
        allExpirations.first as Map<String, dynamic>,
      )
          : null,
      progress: PointsProgress.fromJson(
        json['ordersProgress'] as Map<String, dynamic>? ?? {},
      ),
      pendingBatchBalance: pendingBatch != null
          ? (pendingBatch['balance'] as num).toInt()
          : 0,
    );
  }
}

class PointsBalance {
  final int availablePoints;
  final double monetaryValueEgp;

  PointsBalance({required this.availablePoints, required this.monetaryValueEgp});
}

class UpcomingExpiration {
  final int points;
  final DateTime expiresAt;

  UpcomingExpiration({required this.points, required this.expiresAt});

  factory UpcomingExpiration.fromJson(Map<String, dynamic> json) {
    return UpcomingExpiration(
      points: (json['points'] as num).toInt(),
      expiresAt: DateTime.parse(json['expiryDate'] as String).toLocal(),
    );
  }
}

class PointsProgress {
  final OrdersBatch ordersBatch;

  PointsProgress({required this.ordersBatch});

  factory PointsProgress.fromJson(Map<String, dynamic> json) {
    return PointsProgress(
      ordersBatch: json.isNotEmpty
          ? OrdersBatch.fromJson(json)
          : OrdersBatch.empty(),
    );
  }
}

class OrdersBatch {
  final int ordersCompletedInCurrentBatch;
  final int requiredOrdersForNextBatch;
  final double percentComplete;

  OrdersBatch({
    required this.ordersCompletedInCurrentBatch,
    required this.requiredOrdersForNextBatch,
    required this.percentComplete,
  });

  factory OrdersBatch.empty() => OrdersBatch(
    ordersCompletedInCurrentBatch: 0,
    requiredOrdersForNextBatch: 1,
    percentComplete: 0,
  );

  factory OrdersBatch.fromJson(Map<String, dynamic> json) {
    return OrdersBatch(
      ordersCompletedInCurrentBatch:
      (json['ordersCompletedInCurrentBatch'] as num).toInt(),
      requiredOrdersForNextBatch:
      (json['requiredOrdersForNextBatch'] as num).toInt(),
      percentComplete: (json['percentComplete'] as num).toDouble(),
    );
  }

  /// 0.0 → 1.0 for LinearProgressIndicator
  double get progressFraction => (percentComplete / 100).clamp(0.0, 1.0);

  int get remainingOrders =>
      (requiredOrdersForNextBatch - ordersCompletedInCurrentBatch)
          .clamp(0, requiredOrdersForNextBatch);
}