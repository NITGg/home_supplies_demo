import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/extract_error_message.dart';
import '../data/models/order_model.dart';
import '../data/repositories/order_repo.dart';
import 'order_states.dart';

enum OrderViewMode { active, history }

class OrderCubit extends Cubit<OrderState> {
  final OrderRepository _repository;

  // Separate caches for active and history
  List<Order> _activeOrders = [];
  int _activeSkip = 0;
  final int _activeLimit = 20;
  int _activeTotalCount = 0;
  bool _activeLoading = false;

  List<Order> _historyOrders = [];
  int _historySkip = 0;
  final int _historyLimit = 20;
  int _historyTotalCount = 0;
  bool _historyLoading = false;

  OrderCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(OrderInitial());

  // ── Load Active Orders ─────────────────────────────────────────────────────

  Future<void> loadActiveOrders({bool loadMore = false}) async {
    if (_activeLoading) return;
    _activeLoading = true; // ✅ guard BOTH paths immediately

    if (!loadMore) {
      safeEmit(OrderLoading());
      _activeOrders = [];
      _activeSkip = 0;
    } else {
      _activeLoading = true;
      safeEmit(OrdersLoadingMore(viewMode: OrderViewMode.active));
    }

    try {
      log(
        'OrderCubit: Loading active orders — skip: $_activeSkip, limit: $_activeLimit',
      );

      // First fetch PENDING orders
      final pendingResponse = await _repository.getOrders(
        skip: _activeSkip,
        limit: _activeLimit,
        status: 'PENDING',
        filterByExpiry: true,
      );

      // Then fetch IN_PROGRESS orders
      final inProgressResponse = await _repository.getOrders(
        skip: _activeSkip,
        limit: _activeLimit,
        status: 'IN_PROGRESS',
      );

      // Combine both lists
      final combinedOrders = [
        ...pendingResponse.orders,
        ...inProgressResponse.orders,
      ];

      // Sort by created date (newest first)
      combinedOrders.sort(
        (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
          a.createdAt ?? DateTime.now(),
        ),
      );

      if (!loadMore) {
        _activeOrders = combinedOrders;
      } else {
        _activeOrders.addAll(combinedOrders);
      }

      // Update skip for next load
      _activeSkip = _activeOrders.length;

      // Total count is sum of both statuses
      _activeTotalCount =
          pendingResponse.totalOrders + inProgressResponse.totalOrders;

      _activeLoading = false;

      log(
        'OrderCubit: Loaded ${_activeOrders.length} active orders out of $_activeTotalCount total',
      );

      safeEmit(
        OrdersLoaded(
          orders: _activeOrders,
          totalCount: _activeTotalCount,
          viewMode: OrderViewMode.active,
        ),
      );
    } catch (e) {
      _activeLoading = false;
      log('OrderCubit: Error loading active orders: $e');
      safeEmit(OrderError(extractErrorMessage(e)));
    }
  }

  // ── Load History Orders ────────────────────────────────────────────────────

  String _historyFilter = 'all'; // NEW

  Future<void> loadHistoryOrders({
    bool loadMore = false,
    String filter = 'all',
  }) async {
    if (_historyLoading) return;

    // Reset pagination when filter changes
    if (!loadMore || filter != _historyFilter) {
      _historyFilter = filter;
      safeEmit(OrderLoading());
      _historyOrders = [];
      _historySkip = 0;
      _historyTotalCount = 0;
    } else {
      _historyLoading = true;
      safeEmit(OrdersLoadingMore(viewMode: OrderViewMode.history));
    }

    try {
      log(
        'OrderCubit: Loading history orders — skip: $_historySkip, limit: $_historyLimit, filter: $_historyFilter',
      );

      List<Order> combinedOrders = [];

      if (_historyFilter == 'DELIVERED') {
        final deliveredResponse = await _repository.getOrders(
          skip: _historySkip,
          limit: _historyLimit,
          status: 'DELIVERED',
        );
        combinedOrders = deliveredResponse.orders;
        _historyTotalCount = deliveredResponse.totalOrders;
      } else if (_historyFilter == 'CANCELLED') {
        final cancelledResponse = await _repository.getOrders(
          skip: _historySkip,
          limit: _historyLimit,
          status: 'CANCELLED',
        );
        combinedOrders = cancelledResponse.orders;
        _historyTotalCount = cancelledResponse.totalOrders;
      } else {
        // 'all' — fetch both
        final deliveredResponse = await _repository.getOrders(
          skip: _historySkip,
          limit: _historyLimit,
          status: 'DELIVERED',
        );
        final cancelledResponse = await _repository.getOrders(
          skip: _historySkip,
          limit: _historyLimit,
          status: 'CANCELLED',
        );
        final expiredResponse = await _repository.getOrders(
          skip: _historySkip,
          limit: _historyLimit,
          status: 'EXPIRED',
        );
        combinedOrders = [
          ...deliveredResponse.orders,
          ...cancelledResponse.orders,
          ...expiredResponse.orders,
        ];
        _historyTotalCount =
            deliveredResponse.totalOrders +
            cancelledResponse.totalOrders +
            cancelledResponse.totalOrders;
      }

      // Sort by completion date (newest first)
      combinedOrders.sort((a, b) {
        final dateA =
            b.deliveredAt ?? b.canceledAt ?? b.createdAt ?? DateTime.now();
        final dateB =
            a.deliveredAt ?? a.canceledAt ?? a.createdAt ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

      if (!loadMore) {
        _historyOrders = combinedOrders;
      } else {
        _historyOrders.addAll(combinedOrders);
      }

      _historySkip = _historyOrders.length;
      _historyLoading = false;

      log(
        'OrderCubit: Loaded ${_historyOrders.length} history orders out of $_historyTotalCount total',
      );

      safeEmit(
        OrdersLoaded(
          orders: _historyOrders,
          totalCount: _historyTotalCount,
          viewMode: OrderViewMode.history,
        ),
      );
    } catch (e) {
      _historyLoading = false;
      log('OrderCubit: Error loading history orders: $e');
      safeEmit(OrderError(extractErrorMessage(e)));
    }
  }

  // Update helper too
  bool canLoadMoreHistory() =>
      _historyOrders.length < _historyTotalCount && !_historyLoading;

  // ── Create Order ───────────────────────────────────────────────────────────

  Future<void> createOrder(
    Order order,
    String paymentMethod, {
    String? couponCode,
    required String estimatedDeliveryFee,
  }) async {
    safeEmit(OrderOperationLoading());
    try {
      log('OrderCubit: Creating order');
      final response = await _repository.createOrder(
        order,
        paymentMethod,
        couponCode: couponCode,
        estimatedDeliveryFee: estimatedDeliveryFee,
      );
      log('OrderCubit: Order created — ${response.order.orderNumber}');

      safeEmit(OrderSuccess(message: response.message, order: response.order));
      // Reload active orders (new order will be PENDING)
      await loadActiveOrders(loadMore: false);
    } catch (e) {
      log('OrderCubit: Error creating order: $e');
      safeEmit(OrderError(extractErrorMessage(e)));
    }
  }


  /// Creates a catalog-purchase order from the cart.
  ///
  /// Sends:
  /// ```json
  /// {
  ///   "type": "CATALOG_PURCHASE",
  ///   "payment_method": "CASH" | "WALLET",
  ///   "coupon_code": "..."   // optional
  /// }
  /// ```
  Future<void> createCatalogOrder({
    required String paymentMethod,
    String? couponCode,
  }) async {
    safeEmit(OrderOperationLoading());
    try {
      log('OrderCubit: Creating catalog order — payment: $paymentMethod');

      final response = await _repository.createCatalogOrder(
        paymentMethod: paymentMethod,
        couponCode: couponCode,
      );

      log('OrderCubit: Catalog order created — ${response.order.orderNumber}');
      safeEmit(OrderSuccess(message: response.message, order: response.order));

      // Reload active orders so the new PENDING order appears immediately.
      await loadActiveOrders(loadMore: false);
    } catch (e) {
      log('OrderCubit: Error creating catalog order: $e');
      safeEmit(OrderError(extractErrorMessage(e)));
    }
  }


  // ── Cancel Order ───────────────────────────────────────────────────────────

  Future<void> cancelOrder(int orderId, String reason) async {
    safeEmit(CancelingOrder());
    try {
      log('OrderCubit: Cancelling order $orderId');
      await _repository.cancelOrder(orderId, reason);
      log('OrderCubit: Order cancelled');

      safeEmit(const OrderCancelled(message: 'Order cancelled successfully'));

      // Reload both lists (order moved from active to history)
      await loadActiveOrders(loadMore: false);
    } catch (e) {
      log('OrderCubit: Error cancelling order: $e');
      safeEmit(OrderCancelError(extractErrorMessage(e)));
    }
  }

  Future<void> retryOrder(int? orderId) async {
    safeEmit(const RetryingOrder());
    try {
      log('OrderCubit: Retrying order $orderId');
      if (orderId == null) {
        throw Exception('Order ID is null');
      }
      final response = await _repository.retryOrder(orderId);
      log('OrderCubit: Order retried — $response');
      safeEmit(
        OrderRetried(
          message: response['message'] ?? 'Order retried successfully',
        ),
      );
      // New order will appear as PENDING in active orders
      await loadActiveOrders(loadMore: false);
    } catch (e) {
      log('OrderCubit: Error retrying order: $e');
      safeEmit(OrderRetryError(extractErrorMessage(e)));
    }
  }

  Future<void> cancelOrderUnavailable({required int orderId}) =>
      cancelOrder(orderId, 'Product unavailable');

  Future<void> cancelOrderOther({required int orderId, required String note}) =>
      cancelOrder(orderId, note);

  // ── Load Proposals ─────────────────────────────────────────────────────────

  Future<void> loadProposals(int orderId) async {
    safeEmit(ProposalsLoading(orderId));
    try {
      log('OrderCubit: Loading proposals for order $orderId');
      final response = await _repository.getOrderProposals(orderId);
      log('OrderCubit: Loaded ${response.proposals.length} proposals');

      safeEmit(ProposalsLoaded(orderId: orderId, proposals: response.proposals));
    } catch (e) {
      log('OrderCubit: Error loading proposals: $e');
      safeEmit(ProposalsError(orderId, extractErrorMessage(e)));
    }
  }

  // ── Accept Proposal ────────────────────────────────────────────────────────

  Future<void> acceptProposal({
    required int orderId,
    required int proposalId,
  }) async {
    safeEmit(ProposalUpdating());
    try {
      log('OrderCubit: Accepting proposal $proposalId for order $orderId');
      await _repository.updateProposalStatus(
        orderId: orderId,
        proposalId: proposalId,
        status: 'ACCEPTED',
      );
      log('OrderCubit: Proposal accepted');
      safeEmit(ProposalAccepted(orderId: orderId, proposalId: proposalId));
      await loadActiveOrders(loadMore: false);
      await loadProposals(orderId);
    } on DioException catch (e) {
      final body = e.response?.data as Map<String, dynamic>?;
      final inner =
          body?['data'] as Map<String, dynamic>?; // ← was body?['meta']

      if (e.response?.statusCode == 400 &&
          inner != null &&
          inner.containsKey('required') &&
          inner.containsKey('current')) {
        final required = ((inner['required'] as num?) ?? 0) / 100.0;
        final current = ((inner['current'] as num?) ?? 0) / 100.0;
        log(
          'OrderCubit: Insufficient balance — required: $required, current: $current',
        );
        safeEmit(
          ProposalAcceptInsufficientBalance(
            required: required,
            current: current,
          ),
        );
        return;
      }

      log('OrderCubit: Error accepting proposal: $e');
      safeEmit(OrderError(extractErrorMessage(e)));
    } catch (e) {
      log('OrderCubit: Error accepting proposal: $e');
      safeEmit(OrderError(extractErrorMessage(e)));
    }
  }

  // ── Reject Proposal ────────────────────────────────────────────────────────

  Future<void> rejectProposal({
    required int orderId,
    required int proposalId,
  }) async {
    safeEmit(ProposalUpdating());
    try {
      log('OrderCubit: Rejecting proposal $proposalId for order $orderId');
      await _repository.updateProposalStatus(
        orderId: orderId,
        proposalId: proposalId,
        status: 'REJECTED',
      );
      log('OrderCubit: Proposal rejected');

      safeEmit(ProposalRejected(orderId: orderId, proposalId: proposalId));
      await loadProposals(orderId);
    } catch (e) {
      log('OrderCubit: Error rejecting proposal: $e');
      safeEmit(OrderError(extractErrorMessage(e)));
    }
  }

  // ── Coupon ─────────────────────────────────────────────────────────────────────

  Future<void> validateCoupon(String code) async {
    safeEmit(CouponValidating());
    try {
      log('OrderCubit: Validating coupon $code');
      final data = await _repository.validateCoupon(code);
      final coupon = data['coupon'] as Map<String, dynamic>;
      final isValid = data['valid'] == true;

      if (!isValid) {
        // Pull the message from the response body instead of hardcoding
        final apiMessage = data['message'] as String? ?? 'errors.invalid';
        safeEmit(CouponInvalid(apiMessage));
        return;
      }

      final validState = CouponValid(
        code: coupon['code'] as String,
        title: (coupon['title'] ?? 'Coupon') as String,
        walletAmountCents: coupon['wallet_amount_cents'] as int?,
        walletPoints: coupon['wallet_points'] as int?,
        discountType: coupon['discount_type'] as String?,
        discountValue: (coupon['discount_value'] as num?)?.toDouble(),
        scope: coupon['scope'] as String?,
      );

      safeEmit(
        CouponRedeemed(
          message: 'Coupon redeemed successfully!',
          coupon: validState,
        ),
      );
    } catch (e) {
      // This handles 4xx/5xx from validate endpoint (e.g. errors.not_found)
      log('OrderCubit: Coupon validation error: $e');
      safeEmit(CouponInvalid(extractErrorMessage(e)));
    }
  }

  // ── Confirm Delivery ───────────────────────────────────────────────────────

  Future<void> confirmDelivery({
    required int orderId,
    required int courierId,
  }) async {
    safeEmit(DeliveryConfirming());
    try {
      log('OrderCubit: Confirming delivery for order $orderId');
      await _repository.confirmDelivery(orderId: orderId, courierId: courierId);
      log('OrderCubit: Delivery confirmed');

      safeEmit(DeliveryConfirmed(orderId: orderId, courierId: courierId));

      // Reload both lists (order moved from active to history)
      await loadActiveOrders(loadMore: false);
    } catch (e) {
      log('OrderCubit: Error confirming delivery: $e');
      safeEmit(OrderError(extractErrorMessage(e)));
    }
  }

  Future<void> respondToPriceAdjustment({
    required int orderId,
    required String status, // 'ACCEPTED' or 'REJECTED'
  }) async {
    safeEmit(PriceAdjustmentResponding());
    try {
      await _repository.respondToPriceAdjustment(
        orderId: orderId,
        status: status,
      );
      safeEmit(PriceAdjustmentResponded(status));
      // Refresh active orders so the card reflects the new state
      loadActiveOrders(loadMore: false);
    } catch (e) {
      safeEmit(OrderError(extractErrorMessage(e)));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool canLoadMoreActive() =>
      _activeOrders.length < _activeTotalCount && !_activeLoading;

  void reset() {
    _activeOrders = [];
    _activeSkip = 0;
    _activeTotalCount = 0;
    _activeLoading = false;

    _historyOrders = [];
    _historySkip = 0;
    _historyTotalCount = 0;
    _historyLoading = false;

    safeEmit(OrderInitial());
  }


  void safeEmit(OrderState state) {
    if (!isClosed) emit(state);
  }
}

