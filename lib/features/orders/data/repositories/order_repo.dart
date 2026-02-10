import '../data_source/order_remote_data_source.dart';
import '../models/order_model.dart';

class OrderRepository {
  final OrderRemoteDataSource _remoteDataSource;

  OrderRepository({
    OrderRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource ?? OrderRemoteDataSource();

  Future<OrderResponse> createOrder(Order order) async {
    return await _remoteDataSource.createOrder(order);
  }
}