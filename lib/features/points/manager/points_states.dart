import '../data/models/points_models.dart';

abstract class PointsState {}

class PointsInitial extends PointsState {}

class PointsLoading extends PointsState {}

class PointsLoaded extends PointsState {
  final PointsRulesModel rules;
  final PointsProgressModel progress;
  final bool isArabic;

  PointsLoaded({
    required this.rules,
    required this.progress,
    required this.isArabic,
  });

  PointsRules get localizedRules => rules.getLocalized(isArabic);
}

class PointsError extends PointsState {
  final String message;
  PointsError({required this.message});
}

// ── Convert Points to Money ──────────────────────────────────────────────────

class ConvertingPoints extends PointsState {}

class PointsConverted extends PointsState {
  final int pointsConverted;
  PointsConverted({required this.pointsConverted});
}

class ConvertPointsError extends PointsState {
  final String message;
  ConvertPointsError({required this.message});
}

// ── Pay Fines with Points ────────────────────────────────────────────────────

class PayingFinesWithPoints extends PointsState {}

class FinesPaidWithPoints extends PointsState {
  final List<int> paidPenaltyIds;
  FinesPaidWithPoints({required this.paidPenaltyIds});
}

class PayFinesError extends PointsState {
  final String message;
  PayFinesError({required this.message});
}