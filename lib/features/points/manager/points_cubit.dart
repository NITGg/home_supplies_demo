import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/extract_error_message.dart';
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
}