import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/extract_error_message.dart';
import '../../../l10n/manager/locale_cubit.dart';
import '../data/repo/points_repo.dart';
import 'points_states.dart';

class PointsCubit extends Cubit<PointsState> {
  final PointsRepository _repository = PointsRepository();

  PointsCubit() : super(PointsInitial());

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
      if (!isClosed) {
        emit(PointsError(message: extractErrorMessage(e)));
      }
    }
  }

  // ── Convert Points to Money ───────────────────────────────────────────────

  Future<void> convertPointsToMoney({
    required int points,
    required int userId,
    required bool isArabic,
  }) async {
    emit(ConvertingPoints());
    try {
      await _repository.convertPointsToMoney(
        userId: userId.toString(),
        pointsToMoney: points,
      );
      if (!isClosed) {
        emit(PointsConverted(pointsConverted: points));
        // Refresh balance after conversion
        await loadPoints(isArabic: isArabic);
      }
    } catch (e) {
      if (!isClosed) {
        emit(ConvertPointsError(message: extractErrorMessage(e)));
      }
    }
  }

  // ── Pay Fines with Points ─────────────────────────────────────────────────

  Future<void> payFinesWithPoints({
    required List<int> penaltyIds,
    required String userId,
  }) async {
    emit(PayingFinesWithPoints());
    try {
      await _repository.payFinesUsingPoints(penaltyIds: penaltyIds, userId: userId);
      if (!isClosed) {
        emit(FinesPaidWithPoints(paidPenaltyIds: penaltyIds));
        await loadPoints(isArabic: LocaleManager.currentLocale == 'ar');
      }
    } catch (e) {
      if (!isClosed) emit(PayFinesError(message: extractErrorMessage(e)));
    }
  }
}