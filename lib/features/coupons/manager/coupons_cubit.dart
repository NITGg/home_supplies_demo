import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/utils/extract_error_message.dart';

import '../data/models/coupns_model.dart';
import '../data/repositories/coupns_repo.dart';
import 'coupons_states.dart';


class CouponCubit extends Cubit<CouponState> {
  final CouponRepository _repository = CouponRepository();

  // Cache
  List<AvailableCouponModel> _availableCoupons = [];
  ActiveCouponModel? _activeCoupon;
  List<CouponHistoryModel> _history = [];
  CouponPaginationModel? _historyPagination;

  CouponCubit() : super(CouponInitial());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed.
  @override
  void emit(CouponState state) {
    if (!isClosed) super.emit(state);
  }

  // ==================== Load All Coupon Data ====================
  Future<void> loadAll() async {
    emit(CouponLoading());
    try {
      final results = await Future.wait([
        _repository.getAvailableCoupons(),
        _repository.getActiveCoupon(),
        _repository.getCouponHistory(page: 1, limit: 20),
      ]);

      _availableCoupons = results[0] as List<AvailableCouponModel>;
      _activeCoupon = results[1] as ActiveCouponModel?;
      final historyResult = results[2] as Map<String, dynamic>;
      _history = historyResult['history'] as List<CouponHistoryModel>;
      _historyPagination =
      historyResult['pagination'] as CouponPaginationModel;

      emit(CouponDataLoaded(
        availableCoupons: _availableCoupons,
        activeCoupon: _activeCoupon,
        history: _history,
        historyPagination: _historyPagination,
      ));
    } catch (e) {
      emit(CouponError(message: extractErrorMessage(e)));
    }
  }

  // ==================== Load More History ====================
  Future<void> loadMoreHistory() async {
    if (_historyPagination == null || !_historyPagination!.hasNext) return;

    final currentState = state;
    if (currentState is CouponDataLoaded) {
      emit(currentState.copyWith(isLoadingMoreHistory: true));
    }

    try {
      final nextPage = (_historyPagination?.page ?? 0) + 1;
      final result =
      await _repository.getCouponHistory(page: nextPage, limit: 20);
      final newItems = result['history'] as List<CouponHistoryModel>;
      _history.addAll(newItems);
      _historyPagination = result['pagination'] as CouponPaginationModel;

      emit(CouponDataLoaded(
        availableCoupons: _availableCoupons,
        activeCoupon: _activeCoupon,
        history: _history,
        historyPagination: _historyPagination,
        isLoadingMoreHistory: false,
      ));
    } catch (e) {
      // keep current data, just stop loading
      if (state is CouponDataLoaded) {
        emit((state as CouponDataLoaded)
            .copyWith(isLoadingMoreHistory: false));
      }
    }
  }

  // ==================== Buy With Wallet ====================
  Future<void> buyWithWallet(int couponId) async {
    emit(CouponBuying());
    try {
      await _repository.buyCouponWithWallet(couponId);
      emit(CouponBuySuccess(message: 'Coupon activated successfully!'));
      await loadAll(); // refresh
    } catch (e) {
      emit(CouponBuyError(message: extractErrorMessage(e)));
    }
  }

  // ==================== Buy With Points ====================
  Future<void> buyWithPoints(int couponId) async {
    emit(CouponBuying());
    try {
      await _repository.buyCouponWithPoints(couponId);
      emit(CouponBuySuccess(message: 'Coupon activated using points!'));
      await loadAll(); // refresh
    } catch (e) {
      emit(CouponBuyError(message: extractErrorMessage(e)));
    }
  }

  // ==================== Getters for quick access ====================
  ActiveCouponModel? get activeCoupon => _activeCoupon;
  List<AvailableCouponModel> get availableCoupons => _availableCoupons;
}