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