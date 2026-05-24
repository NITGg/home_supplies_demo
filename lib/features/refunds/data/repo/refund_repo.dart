
import 'dart:io';

import '../data_source/refund_remote_data_source.dart';
import '../models/refund_model.dart';

class RefundRepository {
  final RefundRemoteDataSource _remote;

  RefundRepository({RefundRemoteDataSource? remote})
      : _remote = remote ?? RefundRemoteDataSource();

  Future<RefundReasonsResponse> getRefundReasons() =>
      _remote.getRefundReasons();

  Future<RefundsListResponse> getRefunds({int skip = 0, int limit = 20}) =>
      _remote.getRefunds(skip: skip, limit: limit);

  Future<Refund> createRefund({
    required int orderId,
    required String reason,
    required List<RefundItemRequest> items,
    List<File>? evidenceImages,
  }) =>
      _remote.createRefund(
        orderId: orderId,
        reason: reason,
        items: items,
        evidenceImages: evidenceImages,
      );
}