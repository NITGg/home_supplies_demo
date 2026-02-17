import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/coupons_repo.dart';
import 'ocupons_states.dart';


class CouponCubit extends Cubit<CouponState> {
  final CouponRepository _repository;

  CouponCubit({CouponRepository? repository})
      : _repository = repository ?? CouponRepositoryImpl(),
        super(CouponInitial());

  Future<void> loadCoupons() async {
    emit(CouponLoading());
    try {
      final response = await _repository.getCoupons();
      emit(CouponsLoaded(
        coupons: response.coupons,
        totalCoupons: response.totalCoupons,
        totalPages: response.totalPages,
      ));
    } catch (e) {
      emit(CouponError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}