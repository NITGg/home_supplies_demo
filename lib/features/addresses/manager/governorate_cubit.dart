import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../data/repo/governorate_repo.dart';
import 'governorate_states.dart';

class GovernorateCubit extends Cubit<GovernorateState> {
  final GovernorateRepository _repository;

  GovernorateCubit({GovernorateRepository? repository})
    : _repository = repository ?? GovernorateRepository(),
      super(GovernorateInitial());

  Future<void> loadGovernorates() async {
    if (!isClosed) {
      emit(GovernorateLoading());
    }
    try {
      dLog('GovernorateCubit: Loading governorates with areas');
      final response = await _repository.getGovernoratesWithAreas();
      dLog(
        'GovernorateCubit: Loaded ${response.governorates.length} governorates',
      );
      if (!isClosed) {
        emit(GovernoratesLoaded(response));
      }
    } catch (e) {
      dLog('GovernorateCubit: Error loading governorates: $e');
      if (!isClosed) {
        emit(GovernorateError(extractErrorMessage(e)));
      }
    }
  }
}
