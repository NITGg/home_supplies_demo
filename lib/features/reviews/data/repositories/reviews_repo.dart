import '../data_source/reviews_remote_data_source.dart';
import '../models/reviews_model.dart';

class ReviewsRepository {
  final ReviewsRemoteDataSource _remoteDataSource;

  ReviewsRepository(this._remoteDataSource);

  Future<ReviewsResponse> getMyReviews({int page = 1, int limit = 20}) async {
    return await _remoteDataSource.getMyReviews(page: page, limit: limit);
  }
}
