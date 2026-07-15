import '../data_source/stats_remote_data_source.dart';
import '../models/stats_models.dart';

class StatsRepository {
  final StatsRemoteDataSource _remoteDataSource;

  StatsRepository(this._remoteDataSource);

  /// GET EARNINGS SUMMARY
  Future<EarningsSummaryResponseModel> getEarningsSummary() async {
    return await _remoteDataSource.getEarningsSummary();
  }

  /// GET EARNINGS HISTORY
  Future<EarningsHistoryResponseModel> getEarningsHistory({
    required int page,
    required int limit,
    String? startDate,
    String? endDate,
  }) async {
    return await _remoteDataSource.getEarningsHistory(
      page: page,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// GET PERFORMANCE
  Future<PerformanceResponseModel> getPerformance({
    String? startDate,
    String? endDate,
  }) async {
    return await _remoteDataSource.getPerformance(
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<BadgeProgressResponseModel> getBadgeProgress() async {
    return await _remoteDataSource.getBadgeProgress();
  }
}