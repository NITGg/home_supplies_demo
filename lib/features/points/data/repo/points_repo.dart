import '../data_source/points_remote_data_source.dart';
import '../models/points_models.dart';

class PointsRepository {
  final PointsDataSource _dataSource = PointsDataSource();

  Future<PointsRulesModel> getPointsRules() async {
    return await _dataSource.getPointsRules();
  }

  Future<PointsProgressModel> getPointsProgress() async {
    return await _dataSource.getPointsProgress();
  }

  Future<void> convertPointsToMoney({
    required String userId,
    required int pointsToMoney,
  }) async {
    return await _dataSource.convertPointsToMoney(
      userId: userId,
      pointsToMoney: pointsToMoney,
    );
  }

  Future<void> payFinesUsingPoints({required List<int> penaltyIds, required String userId}) async {
    return await _dataSource.payFinesUsingPoints(penaltyIds: penaltyIds, userId:userId);
  }
}