import 'package:equatable/equatable.dart';
import '../data/models/points_models.dart';

abstract class PointsState extends Equatable {
  const PointsState();

  @override
  List<Object?> get props => [];
}

class PointsInitial extends PointsState {
  const PointsInitial();
}

class PointsLoading extends PointsState {
  const PointsLoading();
}

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

// ── Pay Fines with Points ────────────────────────────────────────────────────

class PayingFinesWithPoints extends PointsState {
  const PayingFinesWithPoints();
}

class FinesPaidWithPoints extends PointsState {
  final List<int> paidPenaltyIds;
  final List<int> paidCommissionIds;

  const FinesPaidWithPoints({
    required this.paidPenaltyIds,
    required this.paidCommissionIds,
  });

  @override
  List<Object?> get props => [paidPenaltyIds, paidCommissionIds];
}

class PayFinesError extends PointsState {
  final String message;
  const PayFinesError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ── Buy Coupon with Points ───────────────────────────────────────────────────

class BuyingCouponWithPoints extends PointsState {
  const BuyingCouponWithPoints();
}

class CouponBoughtWithPoints extends PointsState {
  final int couponId;
  const CouponBoughtWithPoints({required this.couponId});

  @override
  List<Object?> get props => [couponId];
}

class BuyCouponWithPointsError extends PointsState {
  final String message;
  const BuyCouponWithPointsError({required this.message});

  @override
  List<Object?> get props => [message];
}
