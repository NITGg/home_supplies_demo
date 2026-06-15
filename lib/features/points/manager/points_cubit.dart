import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/safe_emit_mixin.dart';
import '../../../l10n/manager/locale_cubit.dart';
import '../data/repo/points_repo.dart';
import 'points_states.dart';

class PointsCubit extends Cubit<PointsState> with SafeEmitMixin<PointsState> {
  final PointsRepository _repository = PointsRepository();

  PointsCubit() : super(PointsInitial());

  Future<void> loadPoints({required bool isArabic}) async {
    safeEmit(PointsLoading());
    try {
      final results = await Future.wait([
        _repository.getPointsRules(),
        _repository.getPointsProgress(),
      ]);

      if (!isClosed) {
        safeEmit(PointsLoaded(
          rules: results[0] as dynamic,
          progress: results[1] as dynamic,
          isArabic: isArabic,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        safeEmit(PointsError(message: extractErrorMessage(e)));
      }
    }
  }

  // ── Convert Points to Money ───────────────────────────────────────────────

  Future<void> convertPointsToMoney({
    required int points,
    required int userId,
    required bool isArabic,
  }) async {
    safeEmit(ConvertingPoints());
    try {
      await _repository.convertPointsToMoney(
        userId: userId.toString(),
        pointsToMoney: points,
      );
      if (!isClosed) {
        safeEmit(PointsConverted(pointsConverted: points));
        // Refresh balance after conversion
        await loadPoints(isArabic: isArabic);
      }
    } catch (e) {
      if (!isClosed) {
        safeEmit(ConvertPointsError(message: extractErrorMessage(e)));
      }
    }
  }

  // ── Pay Fines with Points ─────────────────────────────────────────────────

  Future<void> payFinesWithPoints({
    required List<int> penaltyIds,
    required String userId,
  }) async {
    safeEmit(PayingFinesWithPoints());
    try {
      await _repository.payFinesUsingPoints(penaltyIds: penaltyIds, userId: userId);
      if (!isClosed) {
        safeEmit(FinesPaidWithPoints(paidPenaltyIds: penaltyIds));
        await loadPoints(isArabic: LocaleManager.currentLocale == 'ar');
      }
    } catch (e) {
      if (!isClosed) safeEmit(PayFinesError(message: extractErrorMessage(e)));
    }
  }
}