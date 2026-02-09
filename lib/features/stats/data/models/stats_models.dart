// stats_models.dart

/// Earnings Summary Models
class EarningsSummaryResponseModel {
  final String message;
  final EarningsSummaryData data;

  EarningsSummaryResponseModel({
    required this.message,
    required this.data,
  });

  factory EarningsSummaryResponseModel.fromJson(Map<String, dynamic> json) {
    return EarningsSummaryResponseModel(
      message: json['message'] as String,
      data: EarningsSummaryData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class EarningsSummaryData {
  final EarningsPeriod today;
  final EarningsPeriod thisWeek;
  final EarningsPeriod thisMonth;
  final EarningsPeriod total;
  final UnpaidCommissions unpaidCommissions;

  EarningsSummaryData({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.total,
    required this.unpaidCommissions,
  });

  factory EarningsSummaryData.fromJson(Map<String, dynamic> json) {
    return EarningsSummaryData(
      today: EarningsPeriod.fromJson(json['today'] as Map<String, dynamic>),
      thisWeek: EarningsPeriod.fromJson(json['this_week'] as Map<String, dynamic>),
      thisMonth: EarningsPeriod.fromJson(json['this_month'] as Map<String, dynamic>),
      total: EarningsPeriod.fromJson(json['total'] as Map<String, dynamic>),
      unpaidCommissions: UnpaidCommissions.fromJson(
        json['unpaid_commissions'] as Map<String, dynamic>,
      ),
    );
  }
}

class EarningsPeriod {
  final num earnings;
  final int deliveries;

  EarningsPeriod({
    required this.earnings,
    required this.deliveries,
  });

  factory EarningsPeriod.fromJson(Map<String, dynamic> json) {
    return EarningsPeriod(
      earnings: json['earnings'] as num,
      deliveries: json['deliveries'] as int,
    );
  }
}

class UnpaidCommissions {
  final int count;
  final num totalAmount;

  UnpaidCommissions({
    required this.count,
    required this.totalAmount,
  });

  factory UnpaidCommissions.fromJson(Map<String, dynamic> json) {
    return UnpaidCommissions(
      count: json['count'] as int,
      totalAmount: json['total_amount'] as num,
    );
  }
}

/// Earnings History Models
class EarningsHistoryResponseModel {
  final String message;
  final EarningsHistoryData data;

  EarningsHistoryResponseModel({
    required this.message,
    required this.data,
  });

  factory EarningsHistoryResponseModel.fromJson(Map<String, dynamic> json) {
    return EarningsHistoryResponseModel(
      message: json['message'] as String,
      data: EarningsHistoryData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class EarningsHistoryData {
  final List<TransactionModel> transactions;
  final PaginationModel pagination;

  EarningsHistoryData({
    required this.transactions,
    required this.pagination,
  });

  factory EarningsHistoryData.fromJson(Map<String, dynamic> json) {
    return EarningsHistoryData(
      transactions: (json['transactions'] as List)
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: PaginationModel.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }
}

class TransactionModel {
  final int id;
  final String type;
  final num amount;
  final String description;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int,
      type: json['type'] as String,
      amount: json['amount'] as num,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PaginationModel {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    return PaginationModel(
      page: json['page'] as int,
      limit: json['limit'] as int,
      total: json['total'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}

/// Performance Models
class PerformanceResponseModel {
  final String message;
  final PerformanceData data;

  PerformanceResponseModel({
    required this.message,
    required this.data,
  });

  factory PerformanceResponseModel.fromJson(Map<String, dynamic> json) {
    return PerformanceResponseModel(
      message: json['message'] as String,
      data: PerformanceData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class PerformanceData {
  final DateRange dateRange;
  final PerformanceStatistics statistics;
  final PeriodStats periodStats;
  final PerformanceAnalytics analytics;

  PerformanceData({
    required this.dateRange,
    required this.statistics,
    required this.periodStats,
    required this.analytics,
  });

  factory PerformanceData.fromJson(Map<String, dynamic> json) {
    return PerformanceData(
      dateRange: DateRange.fromJson(json['date_range'] as Map<String, dynamic>),
      statistics: PerformanceStatistics.fromJson(
        json['statistics'] as Map<String, dynamic>,
      ),
      periodStats: PeriodStats.fromJson(
        json['period_stats'] as Map<String, dynamic>,
      ),
      analytics: PerformanceAnalytics.fromJson(
        json['analytics'] as Map<String, dynamic>,
      ),
    );
  }
}

class DateRange {
  final String startDate;
  final String endDate;

  DateRange({
    required this.startDate,
    required this.endDate,
  });

  factory DateRange.fromJson(Map<String, dynamic> json) {
    return DateRange(
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
    );
  }
}

class PerformanceStatistics {
  final int totalCompletedOrders;
  final int totalCancelledOrders;
  final num averageRating;
  final int totalReviews;
  final num acceptanceRate;
  final num completionRate;
  final num avgDeliveryTime;

  PerformanceStatistics({
    required this.totalCompletedOrders,
    required this.totalCancelledOrders,
    required this.averageRating,
    required this.totalReviews,
    required this.acceptanceRate,
    required this.completionRate,
    required this.avgDeliveryTime,
  });

  factory PerformanceStatistics.fromJson(Map<String, dynamic> json) {
    return PerformanceStatistics(
      totalCompletedOrders: json['total_completed_orders'] as int,
      totalCancelledOrders: json['total_cancelled_orders'] as int,
      averageRating: json['average_rating'] as num,
      totalReviews: json['total_reviews'] as int,
      acceptanceRate: json['acceptance_rate'] as num,
      completionRate: json['completion_rate'] as num,
      avgDeliveryTime: json['avg_delivery_time'] as num,
    );
  }
}

class PeriodStats {
  final int completedOrders;
  final int cancelledOrders;
  final num earnings;
  final int totalProposals;
  final int acceptedProposals;
  final num acceptanceRate;
  final num completionRate;

  PeriodStats({
    required this.completedOrders,
    required this.cancelledOrders,
    required this.earnings,
    required this.totalProposals,
    required this.acceptedProposals,
    required this.acceptanceRate,
    required this.completionRate,
  });

  factory PeriodStats.fromJson(Map<String, dynamic> json) {
    return PeriodStats(
      completedOrders: json['completed_orders'] as int,
      cancelledOrders: json['cancelled_orders'] as int,
      earnings: json['earnings'] as num,
      totalProposals: json['total_proposals'] as int,
      acceptedProposals: json['accepted_proposals'] as int,
      acceptanceRate: json['acceptance_rate'] as num,
      completionRate: json['completion_rate'] as num,
    );
  }
}

class PerformanceAnalytics {
  final List<EarningsChartData> earningsChart;
  final List<PerformingArea> bestPerformingAreas;

  PerformanceAnalytics({
    required this.earningsChart,
    required this.bestPerformingAreas,
  });

  factory PerformanceAnalytics.fromJson(Map<String, dynamic> json) {
    return PerformanceAnalytics(
      earningsChart: (json['earnings_chart'] as List)
          .map((e) => EarningsChartData.fromJson(e as Map<String, dynamic>))
          .toList(),
      bestPerformingAreas: (json['best_performing_areas'] as List)
          .map((e) => PerformingArea.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class EarningsChartData {
  final String date;
  final num earnings;
  final int ordersCount;

  EarningsChartData({
    required this.date,
    required this.earnings,
    required this.ordersCount,
  });

  factory EarningsChartData.fromJson(Map<String, dynamic> json) {
    return EarningsChartData(
      date: json['date'] as String,
      earnings: json['earnings'] as num,
      ordersCount: json['orders_count'] as int,
    );
  }
}

class PerformingArea {
  final int areaId;
  final String areaName;
  final String areaNameAr;
  final int ordersCount;
  final num earnings;

  PerformingArea({
    required this.areaId,
    required this.areaName,
    required this.areaNameAr,
    required this.ordersCount,
    required this.earnings,
  });

  factory PerformingArea.fromJson(Map<String, dynamic> json) {
    return PerformingArea(
      areaId: json['area_id'] as int,
      areaName: json['area_name'] as String,
      areaNameAr: json['area_name_ar'] as String,
      ordersCount: json['orders_count'] as int,
      earnings: json['earnings'] as num,
    );
  }
}