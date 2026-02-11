import '../data_source/order_remote_data_source.dart';
import '../models/order_model.dart';
import '../models/proposal_model.dart';

class OrderRepository {
  final OrderRemoteDataSource _remoteDataSource;

  OrderRepository({OrderRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? OrderRemoteDataSource();

  // Create Order
  Future<OrderResponse> createOrder(Order order) async {
    return await _remoteDataSource.createOrder(order);
  }

  // Get All Orders (with pagination)
  Future<OrdersListResponse> getOrders({
    int skip = 0,
    int limit = 20,
    String? status,
  }) async {
    return await _remoteDataSource.getOrders(
      skip: skip,
      limit: limit,
      status: status,
    );
  }

  // Cancel Order
  Future<void> cancelOrder(int orderId, String reason) async {
    return await _remoteDataSource.cancelOrder(orderId, reason);
  }

  // Load Proposals for an Order
  Future<ProposalsResponse> getOrderProposals(int orderId) async {
    return await _remoteDataSource.getOrderProposals(orderId);
  }

  // Accept or Reject Proposal
  Future<Map<String, dynamic>> updateProposalStatus({
    required int orderId,
    required int proposalId,
    required String status, // 'ACCEPTED' or 'REJECTED'
  }) async {
    return await _remoteDataSource.updateProposalStatus(
      orderId: orderId,
      proposalId: proposalId,
      status: status,
    );
  }

  // Confirm Delivery
  Future<Map<String, dynamic>> confirmDelivery({
    required int orderId,
    required int courierId,
  }) async {
    return await _remoteDataSource.confirmDelivery(
      orderId: orderId,
      courierId: courierId,
    );
  }
}
