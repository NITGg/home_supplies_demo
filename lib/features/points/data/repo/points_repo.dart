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
}