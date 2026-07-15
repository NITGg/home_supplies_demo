import 'package:equatable/equatable.dart';
import '../data/models/coupns_model.dart';

abstract class CouponState extends Equatable {
  const CouponState();

  @override
  List<Object?> get props => [];
}

class CouponInitial extends CouponState {
  const CouponInitial();
}

// ── Loading ──────────────────────────────────────────────
class CouponLoading extends CouponState {
  const CouponLoading();
}

class CouponBuying extends CouponState {
  const CouponBuying();
}

// ── Loaded ───────────────────────────────────────────────
class CouponDataLoaded extends CouponState {
  final List<AvailableCouponModel> availableCoupons;
  final ActiveCouponModel? activeCoupon;
  final List<CouponHistoryModel> history;
  final CouponPaginationModel? historyPagination;
  final bool isLoadingMoreHistory;

  const CouponDataLoaded({
    required this.availableCoupons,
    required this.activeCoupon,
    required this.history,
    this.historyPagination,
    this.isLoadingMoreHistory = false,
  });

  CouponDataLoaded copyWith({
    List<AvailableCouponModel>? availableCoupons,
    ActiveCouponModel? Function()? activeCoupon,
    List<CouponHistoryModel>? history,
    CouponPaginationModel? historyPagination,
    bool? isLoadingMoreHistory,
  }) {
    return CouponDataLoaded(
      availableCoupons: availableCoupons ?? this.availableCoupons,
      activeCoupon:
      activeCoupon != null ? activeCoupon() : this.activeCoupon,
      history: history ?? this.history,
      historyPagination: historyPagination ?? this.historyPagination,
      isLoadingMoreHistory:
      isLoadingMoreHistory ?? this.isLoadingMoreHistory,
    );
  }

  @override
  List<Object?> get props => [
    availableCoupons,
    activeCoupon,
    history,
    historyPagination,
    isLoadingMoreHistory,
  ];
}

class CouponBuySuccess extends CouponState {
  final String message;

  const CouponBuySuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

// ── Error ─────────────────────────────────────────────────
class CouponError extends CouponState {
  final String message;

  const CouponError({required this.message});

  @override
  List<Object?> get props => [message];
}

class CouponBuyError extends CouponState {
  final String message;

  const CouponBuyError({required this.message});

  @override
  List<Object?> get props => [message];
}
