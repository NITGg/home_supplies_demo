import 'package:equatable/equatable.dart';
import '../data/models/points_models.dart';

abstract class PointsState extends Equatable {
  const PointsState();

  @override
  List<Object?> get props => [];
}

class PointsInitial extends PointsState {}

class PointsLoading extends PointsState {}

class PointsLoaded extends PointsState {
  final PointsRulesModel rules;
  final PointsProgressModel progress;
  final bool isArabic;

  const PointsLoaded({
    required this.rules,
    required this.progress,
    required this.isArabic,
  });

  PointsRules get localizedRules => rules.getLocalized(isArabic);

  @override
  List<Object?> get props => [rules, progress, isArabic];
}

class PointsError extends PointsState {
  final String message;
  const PointsError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ── Convert Points to Money ──────────────────────────────────────────────────

class ConvertingPoints extends PointsState {}

class PointsConverted extends PointsState {
  final int pointsConverted;
  const PointsConverted({required this.pointsConverted});

  @override
  List<Object?> get props => [pointsConverted];
}

class ConvertPointsError extends PointsState {
  final String message;
  const ConvertPointsError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ── Pay Fines with Points ────────────────────────────────────────────────────

class PayingFinesWithPoints extends PointsState {}

class FinesPaidWithPoints extends PointsState {
  final List<int> paidPenaltyIds;
  const FinesPaidWithPoints({required this.paidPenaltyIds});

  @override
  List<Object?> get props => [paidPenaltyIds];
}

class PayFinesError extends PointsState {
  final String message;
  const PayFinesError({required this.message});

  @override
  List<Object?> get props => [message];
}