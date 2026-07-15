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

  Future<void> payFinesUsingPoints({
    required List<int> penaltyIds,
    required List<int> commissionIds,
    required String userId,
  }) async {
    return await _dataSource.payFinesUsingPoints(
      penaltyIds: penaltyIds,
      commissionIds: commissionIds,
      userId: userId,
    );
  }

  Future<void> buyCouponUsingPoints({required int couponId}) async {
    return await _dataSource.buyCouponUsingPoints(couponId: couponId);
  }
}