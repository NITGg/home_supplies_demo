import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/utils/extract_error_message.dart';
import '../data/repo/points_repo.dart';
import 'points_states.dart';

class PointsCubit extends Cubit<PointsState> {
  final PointsRepository _repository = PointsRepository();

  PointsCubit() : super(PointsInitial());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed.
  @override
  void emit(PointsState state) {
    if (!isClosed) super.emit(state);
  }

  // ==================== Load Points ====================
  Future<void> loadPoints({required bool isArabic}) async {
    emit(PointsLoading());
    try {
      final results = await Future.wait([
        _repository.getPointsRules(),
        _repository.getPointsProgress(),
      ]);
      if (!isClosed) {
        emit(PointsLoaded(
          rules: results[0] as dynamic,
          progress: results[1] as dynamic,
          isArabic: isArabic,
        ));
      }
    } catch (e) {
      if (!isClosed) emit(PointsError(message: extractErrorMessage(e)));
    }
  }

  // ==================== Pay Fines with Points ====================
  /// Pass non-empty [penaltyIds] when called from PenaltiesScreen.
  /// Pass non-empty [commissionIds] when called from UnpaidCommissionsScreen.
  /// Both lists can be non-empty if you ever want to pay mixed items.
  Future<void> payFinesWithPoints({
    List<int> penaltyIds = const [],
    List<int> commissionIds = const [],
    required String userId,
  }) async {
    emit(PayingFinesWithPoints());
    try {
      await _repository.payFinesUsingPoints(
        penaltyIds: penaltyIds,
        commissionIds: commissionIds,
        userId: userId,
      );
      if (!isClosed) {
        emit(FinesPaidWithPoints(
          paidPenaltyIds: penaltyIds,
          paidCommissionIds: commissionIds,
        ));
      }
    } catch (e) {
      if (!isClosed) emit(PayFinesError(message: extractErrorMessage(e)));
    }
  }
}