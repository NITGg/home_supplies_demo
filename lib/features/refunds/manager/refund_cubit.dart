
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/safe_emit_mixin.dart';
import '../data/models/refund_model.dart';
import '../data/repo/refund_repo.dart';
import 'refund_states.dart';

class RefundCubit extends Cubit<RefundState> with SafeEmitMixin<RefundState> {
  final RefundRepository _repo;

  List<Refund> _refunds = [];
  int _skip = 0;
  final int _limit = 20;
  int _total = 0;
  bool _loading = false;

  RefundCubit({RefundRepository? repo})
      : _repo = repo ?? RefundRepository(),
        super(RefundInitial());

  // ── Reasons ──────────────────────────────────────────────────────────────

  Future<void> loadReasons() async {
    _safeEmit(RefundReasonsLoading());
    try {
      final res = await _repo.getRefundReasons();
      _safeEmit(RefundReasonsLoaded(res.reasons));
    } catch (e) {
      dLog('[RefundCubit] loadReasons error: $e');
      _safeEmit(RefundReasonsError(extractErrorMessage(e)));
    }
  }

  // ── Refunds list ──────────────────────────────────────────────────────────

  Future<void> loadRefunds({bool loadMore = false}) async {
    if (_loading) return;
    _loading = true;

    if (!loadMore) {
      _safeEmit(RefundsLoading());
      _refunds = [];
      _skip = 0;
      _total = 0;
    } else {
      _safeEmit(RefundsLoadingMore());
    }

    try {
      final res = await _repo.getRefunds(skip: _skip, limit: _limit);

      if (!loadMore) {
        _refunds = res.refunds;
      } else {
        _refunds.addAll(res.refunds);
      }

      _skip = _refunds.length;
      _total = res.total;
      _loading = false;

      _safeEmit(RefundsLoaded(refunds: List.unmodifiable(_refunds), total: _total));
    } catch (e) {
      _loading = false;
      dLog('[RefundCubit] loadRefunds error: $e');
      _safeEmit(RefundsError(extractErrorMessage(e)));
    }
  }

  bool get canLoadMore => _refunds.length < _total && !_loading;

  // ── Create refund ─────────────────────────────────────────────────────────

  Future<void> createRefund({
    required int orderId,
    required String reason,
    required List<RefundItemRequest> items,
    List<File>? evidenceImages,
  }) async {
    _safeEmit(RefundSubmitting());
    try {
      final refund = await _repo.createRefund(
        orderId: orderId,
        reason: reason,
        items: items,
        evidenceImages: evidenceImages,
      );
      dLog('[RefundCubit] refund created id=${refund.id}');
      _safeEmit(RefundSubmitted(refund));
    } catch (e) {
      dLog('[RefundCubit] createRefund error: $e');
      _safeEmit(RefundSubmitError(extractErrorMessage(e)));
    }
  }

  void _safeEmit(RefundState s) {
    if (!isClosed) safeEmit(s);
  }
}