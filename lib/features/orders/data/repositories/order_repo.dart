import '../data_source/order_remote_data_source.dart';
import '../models/order_model.dart';
import '../models/proposal_model.dart';

class OrderRepository {
  final OrderRemoteDataSource _remoteDataSource;

  OrderRepository({OrderRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? OrderRemoteDataSource();

  // Create Order
  Future<OrderResponse> createOrder(
    Order order,
    String paymentMethod, {
    String? couponCode,
    required String estimatedDeliveryFee,
  }) async {
    return await _remoteDataSource.createOrder(
      order,
      paymentMethod,
      couponCode: couponCode,
      estimatedDeliveryFee: estimatedDeliveryFee,
    );
  }

  Future<OrderResponse> createCatalogOrder({
    required String paymentMethod,
    String? couponCode,
  }) async {
    return await _remoteDataSource.createCatalogOrder(
      paymentMethod: paymentMethod,
      couponCode: couponCode,
    );
  }

  // Get All Orders (with pagination)
  Future<OrdersListResponse> getOrders({
    int skip = 0,
    int limit = 20,
    String? status,
    bool filterByExpiry = false,
  }) async {
    return await _remoteDataSource.getOrders(
      skip: skip,
      limit: limit,
      status: status,
      filterByExpiry: filterByExpiry,
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

  Future<Map<String, dynamic>> respondToPriceAdjustment({
    required int orderId,
    required String status, // 'ACCEPTED' or 'REJECTED'
  }) async {
    return await _remoteDataSource.respondToPriceAdjustment(
      orderId: orderId,
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

  Future<Map<String, dynamic>> validateCoupon(String code) async {
    return await _remoteDataSource.validateCoupon(code);
  }

  Future<Map<String, dynamic>> redeemCoupon(String code) async {
    return await _remoteDataSource.redeemCoupon(code);
  }

  Future<Map<String, dynamic>> retryOrder(int orderId) async {
    return await _remoteDataSource.retryOrder(orderId);
  }
}
