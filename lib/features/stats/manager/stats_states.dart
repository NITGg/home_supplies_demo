import '../data/models/stats_models.dart';

abstract class StatsState {}

class StatsInitial extends StatsState {}

// Earnings Summary States
class EarningsSummaryLoading extends StatsState {}

class EarningsSummaryLoaded extends StatsState {
  final EarningsSummaryData earningsSummary;

  EarningsSummaryLoaded({required this.earningsSummary});
}

// Earnings History States
class EarningsHistoryLoading extends StatsState {}

class EarningsHistoryLoaded extends StatsState {
  final EarningsHistoryData earningsHistory;

  EarningsHistoryLoaded({required this.earningsHistory});
}

// Performance States
class PerformanceLoading extends StatsState {}

class PerformanceLoaded extends StatsState {
  final PerformanceData performance;

  PerformanceLoaded({required this.performance});
}

// Error State
class StatsFailure extends StatsState {
  final String message;

  StatsFailure(this.message);
}