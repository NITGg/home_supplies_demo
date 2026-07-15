import 'package:flutter/material.dart';

import '../data_source/orders_remote_data_source.dart';
import '../models/orders_model.dart';

class OrderRepository {
  final OrderDataSource _dataSource = OrderDataSource();

  /// Invalidate the cached GPS position so the next [getAvailableOrders] call
  /// (with [forceRefreshLocation] = true) fetches a fresh fix.
  void invalidateLocationCache() => _dataSource.invalidateLocationCache();

  Future<Map<String, dynamic>> getAvailableOrders({
    int page = 1,
    int limit = 20,
    double? minBudget,
    double? maxBudget,
    required BuildContext context,
    // true  → explicit pull-to-refresh (always re-GPS)
    // false → socket-triggered reload   (reuse cached position)
    bool forceRefreshLocation = false,
  }) async {
    return await _dataSource.getAvailableOrders(
      page: page,
      limit: limit,
      minBudget: minBudget,
      maxBudget: maxBudget,
      context: context,
      forceRefreshLocation: forceRefreshLocation,
    );
  }

  Future<OrderModel?> fetchOrderById(int orderId) async {
    try {
      return await _dataSource.getOrderById(orderId);
    } catch (e) {
      return null;
    }
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

  Future<ProposalModel> submitOffer({
    required int orderId,
    required int totalFee,
    required double distanceToPickup,
    required int timeToPickup,
    required int vehicleId,
  }) async {
    return await _dataSource.submitOffer(
      orderId: orderId,
      totalFee: totalFee,
      distanceToPickup: distanceToPickup,
      timeToPickup: timeToPickup,
      vehicleId: vehicleId,
    );
  }

  /// Respond to a fixed-fee order with ACCEPT or REJECT
  Future<void> respondToFixedFee({
    required int orderId,
    required String action,
  }) async {
    await _dataSource.respondToFixedFee(orderId: orderId, action: action);
  }

  Future<List<OrderModel>> getActiveOrder() async {
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

  Future<bool> aboveWalletLimit(BuildContext context) async {
    return await _dataSource.aboveWalletLimit(context);
  }

  Future<OrderModel> markOrderCollected({required int orderId}) async {
    return await _dataSource.markOrderCollected(orderId: orderId);
  }

  Future<void> confirmWithOtp({
    required int orderId,
    required double actualPrice,
    required String otp,
  }) async {
    await _dataSource.confirmWithOtp(
      orderId: orderId,
      actualPrice: actualPrice,
      otp: otp,
    );
  }

  Future<void> confirmDeliveryFinal({
    required int orderId,
    required int courierId,
  }) async {
    await _dataSource.confirmDeliveryFinal(
      orderId: orderId,
      courierId: courierId,
    );
  }
}