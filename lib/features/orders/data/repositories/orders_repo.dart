import '../data_source/orders_remote_data_source.dart';
import '../models/orders_model.dart';

class OrderRepository {
  final OrderDataSource _dataSource = OrderDataSource();

  Future<Map<String, dynamic>> getAvailableOrders({
    int page = 1,
    int limit = 20,
  }) async {
    return await _dataSource.getAvailableOrders(page: page, limit: limit);
  }

  Future<Map<String, dynamic>> getOrderHistory({
    int page = 1,
    int limit = 20,
    String filter = 'all',
  }) async {
    return await _dataSource.getOrderHistory(
      page: page,
      limit: limit,
      filter: filter,
    );
  }

  Future<OrderModel> getOrderDetails(int orderId) async {
    return await _dataSource.getOrderDetails(orderId);
  }

  Future<FeeRangeModel> getAllowedFeeRange(int orderId) async {
    return await _dataSource.getAllowedFeeRange(orderId);
  }

  Future<ProposalModel> submitOffer({
    required int orderId,
    required double totalFee,
  }) async {
    return await _dataSource.submitOffer(orderId: orderId, totalFee: totalFee);
  }

  Future<OrderModel?> getActiveOrder() async {
    return await _dataSource.getActiveOrder();
  }

  Future<QrCodeModel> completeDelivery({
    required int orderId,
    required double actualPrice,
  }) async {
    return await _dataSource.completeDelivery(
      orderId: orderId,
      actualPrice: actualPrice,
    );
  }

  Future<OrderModel> reportHighPrice({
    required int orderId,
    required double actualPrice,
  }) async {
    return await _dataSource.reportHighPrice(
      orderId: orderId,
      actualPrice: actualPrice,
    );
  }

  Future<OrderModel> cancelOrderUnavailable({
    required int orderId,
    required String note,
  }) async {
    return await _dataSource.cancelOrderUnavailable(
      orderId: orderId,
      note: note,
    );
  }

  Future<OrderModel> cancelOrderOther({
    required int orderId,
    required String note,
  }) async {
    return await _dataSource.cancelOrderOther(orderId: orderId, note: note);
  }
}
