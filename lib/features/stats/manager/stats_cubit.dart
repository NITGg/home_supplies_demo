import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/features/stats/manager/stats_states.dart';

import '../data/models/stats_models.dart';
import '../data/repository/stats_repo.dart';

class StatsCubit extends Cubit<StatsState> {
  final StatsRepository _repository;

  EarningsSummaryData? _earningsSummary;
  EarningsHistoryData? _earningsHistory;
  PerformanceData? _performance;

  StatsCubit(this._repository) : super(StatsInitial());

  // Getters for current data
  EarningsSummaryData? get earningsSummary => _earningsSummary;
  EarningsHistoryData? get earningsHistory => _earningsHistory;
  PerformanceData? get performance => _performance;

  /// FETCH EARNINGS SUMMARY
  Future<void> fetchEarningsSummary() async {
    emit(EarningsSummaryLoading());
    try {
      final result = await _repository.getEarningsSummary();
      _earningsSummary = result.data;
      emit(EarningsSummaryLoaded(earningsSummary: result.data));
    } on DioException catch (e) {
      log('StatsCubit fetchEarningsSummary DioException: $e');
      log('Response data: ${e.response?.data}');
      log('Status code: ${e.response?.statusCode}');
      emit(StatsFailure(_extractErrorMessage(e)));
    } catch (e) {
      log('StatsCubit fetchEarningsSummary error: $e');
      emit(StatsFailure(_extractErrorMessage(e)));
    }
  }

  /// FETCH EARNINGS HISTORY
  Future<void> fetchEarningsHistory({
    required int page,
    required int limit,
    int skip = 0,
    String? startDate,
    String? endDate,
  }) async {
    emit(EarningsHistoryLoading());
    try {
      final result = await _repository.getEarningsHistory(
        page: page,
        limit: limit,
        skip: skip,
        startDate: startDate,
        endDate: endDate,
      );
      _earningsHistory = result.data;
      emit(EarningsHistoryLoaded(earningsHistory: result.data));
    } on DioException catch (e) {
      log('StatsCubit fetchEarningsHistory DioException: $e');
      log('Response data: ${e.response?.data}');
      log('Status code: ${e.response?.statusCode}');
      emit(StatsFailure(_extractErrorMessage(e)));
    } catch (e) {
      log('StatsCubit fetchEarningsHistory error: $e');
      emit(StatsFailure(_extractErrorMessage(e)));
    }
  }

  /// FETCH PERFORMANCE
  Future<void> fetchPerformance({
    String? startDate,
    String? endDate,
  }) async {
    emit(PerformanceLoading());
    try {
      final result = await _repository.getPerformance(
        startDate: startDate,
        endDate: endDate,
      );
      _performance = result.data;
      emit(PerformanceLoaded(performance: result.data));
    } on DioException catch (e) {
      log('StatsCubit fetchPerformance DioException: $e');
      log('Response data: ${e.response?.data}');
      log('Status code: ${e.response?.statusCode}');
      emit(StatsFailure(_extractErrorMessage(e)));
    } catch (e) {
      log('StatsCubit fetchPerformance error: $e');
      emit(StatsFailure(_extractErrorMessage(e)));
    }
  }

  /// FETCH ALL STATS
  /// Convenience method to fetch all stats at once
  Future<void> fetchAllStats({
    String? startDate,
    String? endDate,
  }) async {
    try {
      await Future.wait([
        fetchEarningsSummary(),
        fetchPerformance(
          startDate: startDate,
          endDate: endDate,
        ),
      ]);
    } catch (e) {
      log('StatsCubit fetchAllStats error: $e');
      emit(StatsFailure(_extractErrorMessage(e)));
    }
  }

  /// Helper function to extract error messages
  String _extractErrorMessage(dynamic e) {
    String message = 'حدث خطأ غير متوقع';

    if (e is DioException) {
      try {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          message = data['message'];
        } else if (data is String) {
          message = data;
        }
      } catch (_) {}
    } else {
      message = e.toString();
    }

    return message;
  }

  void reset() {
    emit(StatsInitial());
  }
}