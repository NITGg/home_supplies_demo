import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/safe_emit_mixin.dart';
import '../../../core/utils/secure_storage_service.dart';
import '../data/models/order_model.dart';
import '../data/repositories/order_repo.dart';
import 'order_states.dart';

enum OrderViewMode { active, history }

class OrderCubit extends Cubit<OrderState> with SafeEmitMixin<OrderState> {
  final OrderRepository _repository;
  bool _isGuest = false;
  void setGuestMode(bool value) => _isGuest = value;

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
    if (_isGuest) return;
    final token = await SecureStorageService().getToken();   // ← self-check
    if (token == null || token.isEmpty) return;
    if (_activeLoading) return;
    _activeLoading = true; // ✅ guard BOTH paths immediately

    if (!loadMore) {
      safeEmit(OrderLoading());
      _activeOrders = [];
      _activeSkip = 0;
    } else {
      safeEmit(OrdersLoadingMore(viewMode: OrderViewMode.active));
    }

    try {
      dLog(
        'OrderCubit: Loading active orders — skip: $_activeSkip, limit: $_activeLimit',
      );

      final [pendingScheduledResponse, inProgressResponse] = await Future.wait([
        _repository.getOrders(
          skip: _activeSkip,
          limit: _activeLimit,
          statusIn: ['SCHEDULED', 'PENDING'],
          filterByExpiry: true,
        ),
        _repository.getOrders(
          skip: _activeSkip,
          limit: _activeLimit,
          status: 'IN_PROGRESS',
          filterByExpiry: false,
        ),
      ]);

      final combinedOrders = [
        ...pendingScheduledResponse.orders,
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

      _activeSkip = _activeOrders.length;

      _activeTotalCount =
          pendingScheduledResponse.totalOrders + inProgressResponse.totalOrders;

      _activeLoading = false;

      dLog(
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
      dLog('OrderCubit: Error loading active orders: $e');
      safeEmit(OrderError(extractErrorMessage(e)));
    }
  }

  // ── Card-payment refresh ──────────────────────────────────────────────────

  /// Called right after a successful card payment. Waits 1 second so the
  /// server has time to process the webhook/callback and update the order
  /// status before we fetch the active orders list.
  void refreshAfterCardPayment() {
    Future.delayed(const Duration(seconds: 1), () {
      loadActiveOrders(loadMore: false);
    });
  }

  // ── Load History Orders ────────────────────────────────────────────────────

  String _historyFilter = 'all'; // NEW

  Future<void> loadHistoryOrders({
    bool loadMore = false,
    String filter = 'all',
  }) async {
    if (_isGuest) return;
    final token = await SecureStorageService().getToken();   // ← self-check
    if (token == null || token.isEmpty) return;
    if (_historyLoading) return;
    _historyLoading = true;

    if (!loadMore || filter != _historyFilter) {
      _historyFilter = filter;
      safeEmit(OrderLoading());
      _historyOrders = [];
      _historySkip = 0;
      _historyTotalCount = 0;
    } else {
      safeEmit(OrdersLoadingMore(viewMode: OrderViewMode.history));
    }

    try {
      dLog(
        'OrderCubit: Loading history orders — skip: $_historySkip, limit: $_historyLimit, filter: $_historyFilter',
      );

      List<Order> combinedOrders;

      if (_historyFilter == 'all') {
        final response = await _repository.getOrders(
          skip: _historySkip,
          limit: _historyLimit,
          statusIn: ['DELIVERED', 'CANCELLED', 'EXPIRED'],
        );
        combinedOrders = response.orders;
        _historyTotalCount = response.totalOrders;
      } else {
        final response = await _repository.getOrders(
          skip: _historySkip,
          limit: _historyLimit,
          status: _historyFilter,
        );
        combinedOrders = response.orders;
        _historyTotalCount = response.totalOrders;
      }

      // Sort by completion date (newest first)
      combinedOrders.sort((a, b) {
        final dateA = a.deliveredAt ?? a.canceledAt ?? a.createdAt ?? DateTime.now();
        final dateB = b.deliveredAt ?? b.canceledAt ?? b.createdAt ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      if (!loadMore) {
        _historyOrders = combinedOrders;
      } else {
        _historyOrders.addAll(combinedOrders);
      }

      _historySkip = _historyOrders.length;
      _historyLoading = false;

      dLog(
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
      dLog('OrderCubit: Error loading history orders: $e');
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
        DateTime? scheduleAt,
        // required String estimatedDeliveryFee,
      }) async {
    safeEmit(OrderOperationLoading());
    try {
      dLog('OrderCubit: Creating order — scheduleAt: $scheduleAt');
      final response = await _repository.createOrder(
        order,
        paymentMethod,
        couponCode: couponCode,
        scheduleAt: scheduleAt,
        // estimatedDeliveryFee: estimatedDeliveryFee,
      );
      dLog('OrderCubit: Order created — ${response.order.orderNumber}');

      safeEmit(OrderSuccess(message: response.message, order: response.order));
      // Reload active orders (new order will be PENDING)
      await loadActiveOrders(loadMore: false);
    } catch (e) {
      dLog('OrderCubit: Error creating order: $e');
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
    DateTime? scheduleAt,
    String? provider, // only sent when paymentMethod == 'CARD'
  }) async {
    safeEmit(OrderOperationLoading());
    try {
      dLog('OrderCubit: Creating catalog order — payment: $paymentMethod, provider: $provider, scheduleAt: $scheduleAt');

      final response = await _repository.createCatalogOrder(
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        scheduleAt: scheduleAt,
        provider: provider,
      );

      dLog('OrderCubit: Catalog order created — ${response.order.orderNumber}, status: ${response.order.status}');

      if (response.order.isPendingPayment) {
        // CARD payment: redirect customer to checkout URL before the order
        // can be confirmed. Do NOT navigate to orders list yet.
        safeEmit(OrderPendingPayment(order: response.order));
      } else {
        safeEmit(OrderSuccess(message: response.message, order: response.order));
        await loadActiveOrders(loadMore: false);
      }
    } catch (e) {
      dLog('OrderCubit: Error creating catalog order: $e');
      safeEmit(OrderError(extractErrorMessage(e)));
    }
  }


  // ── Cancel Order ───────────────────────────────────────────────────────────

  Future<void> cancelOrder(int orderId, String reason) async {
    safeEmit(CancelingOrder());
    try {
      dLog('OrderCubit: Cancelling order $orderId');
      await _repository.cancelOrder(orderId, reason);
      dLog('OrderCubit: Order cancelled');

      safeEmit(const OrderCancelled(message: 'Order cancelled successfully'));

      // Reload both lists (order moved from active to history)
      await loadActiveOrders(loadMore: false);
    } catch (e) {
      dLog('OrderCubit: Error cancelling order: $e');
      safeEmit(OrderCancelError(extractErrorMessage(e)));
    }
  }

  Future<void> retryOrder(int? orderId) async {
    safeEmit(const RetryingOrder());
    try {
      dLog('OrderCubit: Retrying order $orderId');
      if (orderId == null) {
        throw Exception('Order ID is null');
      }
      final response = await _repository.retryOrder(orderId);
      dLog('OrderCubit: Order retried — $response');
      safeEmit(
        OrderRetried(
          message: response['message'] ?? 'Order retried successfully',
        ),
      );
      // New order will appear as PENDING in active orders
      await loadActiveOrders(loadMore: false);
    } catch (e) {
      dLog('OrderCubit: Error retrying order: $e');
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
      dLog('OrderCubit: Loading proposals for order $orderId');
      final response = await _repository.getOrderProposals(orderId);
      dLog('OrderCubit: Loaded ${response.proposals.length} proposals');

      safeEmit(ProposalsLoaded(orderId: orderId, proposals: response.proposals));
    } catch (e) {
      dLog('OrderCubit: Error loading proposals: $e');
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
      dLog('OrderCubit: Accepting proposal $proposalId for order $orderId');
      await _repository.updateProposalStatus(
        orderId: orderId,
        proposalId: proposalId,
        status: 'ACCEPTED',
      );
      dLog('OrderCubit: Proposal accepted');
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
        dLog(
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

      dLog('OrderCubit: Error accepting proposal: $e');
      safeEmit(OrderError(extractErrorMessage(e)));
    } catch (e) {
      dLog('OrderCubit: Error accepting proposal: $e');
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
      dLog('OrderCubit: Rejecting proposal $proposalId for order $orderId');
      await _repository.updateProposalStatus(
        orderId: orderId,
        proposalId: proposalId,
        status: 'REJECTED',
      );
      dLog('OrderCubit: Proposal rejected');

      safeEmit(ProposalRejected(orderId: orderId, proposalId: proposalId));
      await loadProposals(orderId);
    } catch (e) {
      dLog('OrderCubit: Error rejecting proposal: $e');
      safeEmit(OrderError(extractErrorMessage(e)));
    }
  }

  // ── Coupon ─────────────────────────────────────────────────────────────────────

  Future<void> validateCoupon(String code, {bool customOrder = false}) async {
    safeEmit(CouponValidating());
    try {
      dLog('OrderCubit: Validating coupon $code');
      final data = await _repository.validateCoupon(code,customOrder);
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
      dLog('OrderCubit: Coupon validation error: $e');
      safeEmit(CouponInvalid(extractErrorMessage(e)));
    }
  }

  // ── Confirm Delivery ───────────────────────────────────────────────────────

  Future<void> confirmDelivery({
    required int orderId,
    required int courierId,
    required int courierUserId,
  }) async {
    safeEmit(DeliveryConfirming());
    try {
      dLog('OrderCubit: Confirming delivery for order $orderId');
      await _repository.confirmDelivery(orderId: orderId, courierId: courierId);
      dLog('OrderCubit: Delivery confirmed');

      safeEmit(DeliveryConfirmed(orderId: orderId, courierId: courierId, courierUserId: courierUserId));

      // Reload both lists (order moved from active to history)
      await loadActiveOrders(loadMore: false);
    } catch (e) {
      dLog('OrderCubit: Error confirming delivery: $e');
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
    _historyFilter = 'all';

    safeEmit(OrderInitial());
  }
}