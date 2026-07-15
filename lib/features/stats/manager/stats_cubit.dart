
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/features/stats/manager/stats_states.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../data/models/stats_models.dart';
import '../data/repository/stats_repo.dart';

class StatsCubit extends Cubit<StatsState> {
  final StatsRepository _repository;

  EarningsSummaryData? _earningsSummary;
  EarningsHistoryData? _earningsHistory;
  PerformanceData? _performance;
  BadgeProgressData? _badgeProgress;

  StatsCubit(this._repository) : super(StatsInitial());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed.
  @override
  void emit(StatsState state) {
    if (!isClosed) super.emit(state);
  }

  // Getters for current data
  EarningsSummaryData? get earningsSummary => _earningsSummary;
  EarningsHistoryData? get earningsHistory => _earningsHistory;
  PerformanceData? get performance => _performance;
  BadgeProgressData? get badgeProgress => _badgeProgress;

  /// FETCH EARNINGS SUMMARY
  Future<void> fetchEarningsSummary() async {
    emit(EarningsSummaryLoading());
    try {
      final result = await _repository.getEarningsSummary();
      _earningsSummary = result.data;
      emit(EarningsSummaryLoaded(earningsSummary: result.data));
    } on DioException catch (e) {
      dLog('StatsCubit fetchEarningsSummary DioException: $e');
      dLog('Response data: ${e.response?.data}');
      dLog('Status code: ${e.response?.statusCode}');
      emit(StatsFailure(extractErrorMessage(e)));
    } catch (e) {
      dLog('StatsCubit fetchEarningsSummary error: $e');
      emit(StatsFailure(extractErrorMessage(e)));
    }
  }

  /// FETCH EARNINGS HISTORY
  Future<void> fetchEarningsHistory({
    required int page,
    required int limit,
    String? startDate,
    String? endDate,
  }) async {
    if (page == 1) {
      _earningsHistory = null;
      emit(EarningsHistoryLoading());
    }
    // page > 1: don't emit loading, keep existing data visible

    try {
      final result = await _repository.getEarningsHistory(
        page: page,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );

      if (page == 1) {
        _earningsHistory = result.data;
      } else {
        _earningsHistory = EarningsHistoryData(
          transactions: [
            ..._earningsHistory!.transactions,
            ...result.data.transactions,
          ],
          pagination: result.data.pagination,
        );
      }

      emit(EarningsHistoryLoaded(earningsHistory: _earningsHistory!));
    } on DioException catch (e) {
      dLog('StatsCubit fetchEarningsHistory DioException: $e');
      emit(StatsFailure(extractErrorMessage(e)));
    } catch (e) {
      dLog('StatsCubit fetchEarningsHistory error: $e');
      emit(StatsFailure(extractErrorMessage(e)));
    }
  }

  /// FETCH PERFORMANCE
  Future<void> fetchPerformance({String? startDate, String? endDate}) async {
    emit(PerformanceLoading());
    try {
      final result = await _repository.getPerformance(
        startDate: startDate,
        endDate: endDate,
      );
      _performance = result.data;
      emit(PerformanceLoaded(performance: result.data));
    } on DioException catch (e) {
      dLog('StatsCubit fetchPerformance DioException: $e');
      dLog('Response data: ${e.response?.data}');
      dLog('Status code: ${e.response?.statusCode}');
      emit(StatsFailure(extractErrorMessage(e)));
    } catch (e) {
      dLog('StatsCubit fetchPerformance error: $e');
      emit(StatsFailure(extractErrorMessage(e)));
    }
  }

  /// FETCH BADGE PROGRESS
  Future<void> fetchBadgeProgress() async {
    emit(BadgeProgressLoading());
    try {
      final result = await _repository.getBadgeProgress();
      _badgeProgress = result.data;
      emit(BadgeProgressLoaded(badgeProgress: result.data));
    } on DioException catch (e) {
      dLog('StatsCubit fetchBadgeProgress DioException: $e');
      dLog('Response data: ${e.response?.data}');
      dLog('Status code: ${e.response?.statusCode}');
      emit(StatsFailure(extractErrorMessage(e)));
    } catch (e) {
      dLog('StatsCubit fetchBadgeProgress error: $e');
      emit(StatsFailure(extractErrorMessage(e)));
    }
  }

  /// FETCH ALL STATS
  /// Convenience method to fetch all stats at once
  Future<void> fetchAllStats({String? startDate, String? endDate}) async {
    try {
      await Future.wait([
        fetchEarningsSummary(),
        fetchPerformance(startDate: startDate, endDate: endDate),
      ]);
    } catch (e) {
      dLog('StatsCubit fetchAllStats error: $e');
      emit(StatsFailure(extractErrorMessage(e)));
    }
  }

  void reset() {
    emit(StatsInitial());
  }
}