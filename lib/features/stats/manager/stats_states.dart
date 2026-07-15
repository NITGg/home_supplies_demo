import 'package:equatable/equatable.dart';
import '../data/models/stats_models.dart';

abstract class StatsState extends Equatable {
  const StatsState();

  @override
  List<Object?> get props => [];
}

class StatsInitial extends StatsState {
  const StatsInitial();
}

// Earnings Summary States
class EarningsSummaryLoading extends StatsState {
  const EarningsSummaryLoading();
}

class EarningsSummaryLoaded extends StatsState {
  final EarningsSummaryData earningsSummary;

  const EarningsSummaryLoaded({required this.earningsSummary});

  @override
  List<Object?> get props => [earningsSummary];
}

// Earnings History States
class EarningsHistoryLoading extends StatsState {
  const EarningsHistoryLoading();
}

class EarningsHistoryLoaded extends StatsState {
  final EarningsHistoryData earningsHistory;

  const EarningsHistoryLoaded({required this.earningsHistory});

  @override
  List<Object?> get props => [earningsHistory];
}

// Performance States
class PerformanceLoading extends StatsState {
  const PerformanceLoading();
}

class PerformanceLoaded extends StatsState {
  final PerformanceData performance;

  const PerformanceLoaded({required this.performance});

  @override
  List<Object?> get props => [performance];
}

// Error State
class StatsFailure extends StatsState {
  final String message;

  const StatsFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class BadgeProgressLoading extends StatsState {
  const BadgeProgressLoading();
}

class BadgeProgressLoaded extends StatsState {
  final BadgeProgressData badgeProgress;

  const BadgeProgressLoaded({required this.badgeProgress});

  @override
  List<Object?> get props => [badgeProgress];
}
