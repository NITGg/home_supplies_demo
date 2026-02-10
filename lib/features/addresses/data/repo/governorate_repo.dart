import '../data_source/governorate_remote_data_source.dart';
import '../models/governorate_model.dart';

class GovernorateRepository {
  final GovernorateRemoteDataSource _remoteDataSource;

  GovernorateRepository({
    GovernorateRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource ?? GovernorateRemoteDataSource();

  Future<GovernoratesResponse> getGovernoratesWithAreas() async {
    return await _remoteDataSource.getGovernoratesWithAreas();
  }
}
