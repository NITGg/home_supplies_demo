import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/app_dynamic_settings.dart';
import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../data/models/orders_model.dart';
import '../data/repositories/orders_repo.dart';
import 'orders_states.dart';

class OrderCubit extends Cubit<OrderState> {
  final OrderRepository _repository;

  // Pagination tracking
  int _availableOrdersPage = 1;
  int _historyPage = 1;
  bool _isLoadingMoreAvailable = false;
  bool _isLoadingMoreHistory = false;
  String _currentHistoryFilter = 'all';

  // Cache for tracking local proposal submissions
  final Set<int> _localProposalCache = {};

  // Latest allowed order price range from the available-orders endpoint.
  // Cached separately from [state] since the cubit's state is overwritten
  // by other emissions (e.g. SubmittingOffer) while on order details.
  PriceRangeModel? _priceRange;

  PriceRangeModel? get priceRange => _priceRange;

  // Latest count of the courier's active orders, cached separately from
  // [state] for the same reason as [_priceRange].
  int _activeOrdersCount = 0;

  int get activeOrdersCount => _activeOrdersCount;

  OrderCubit(this._repository) : super(AvailableOrdersInitial());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed.
  @override
  void emit(OrderState state) {
    if (!isClosed) super.emit(state);
  }

  /// Marks orders whose price (budget for custom orders, products total for
  /// catalog orders) falls outside [_priceRange]'s currently allowed range
  /// with [OrderModel.isOutOfPriceRange] so the UI can render them greyed
  /// out. Orders are no longer hidden — they remain in the returned list.
  List<OrderModel> _markOrdersOutsidePriceRange(List<OrderModel> orders) {
    final range = _priceRange;
    if (range == null) return orders;

    final result = <OrderModel>[];
    final outOfRange = <OrderModel>[];

    for (final order in orders) {
      final relevantPrice =
          order.isCatalogPurchase ? order.productsTotal : order.budget;
      final price = double.tryParse(relevantPrice ?? '');

      final inRange = price == null ||
          (price >= range.allowedMinOrderPrice &&
              price <= range.allowedMaxOrderPrice);

      if (inRange) {
        result.add(order);
      } else {
        final marked = order.copyWith(isOutOfPriceRange: true);
        result.add(marked);
        outOfRange.add(marked);
      }
    }

    if (outOfRange.isNotEmpty) {
      dLog(
        'Marking ${outOfRange.length} order(s) outside allowed price range '
        '(allowed_min=${range.allowedMinOrderPrice}, '
        'allowed_max=${range.allowedMaxOrderPrice}): '
        '${outOfRange.map((o) => 'orderId=${o.id} '
            'price=${o.isCatalogPurchase ? o.productsTotal : o.budget}').join(', ')}',
      );
    }

    return result;
  }

  // ============== Available Orders ==============

  void clearAvailableOrders() {
    _availableOrdersPage = 1;
    _isLoadingMoreAvailable = false;
    if (isClosed) return;

    emit(
      const AvailableOrdersLoaded(orders: [], pagination: {}, hasMore: false),
    );
  }

  bool _availableFetchBlocked = false;

  void blockAvailableOrdersFetch() {
    _availableFetchBlocked = true;
    _availableOrdersPage = 1;
    _isLoadingMoreAvailable = false;
    if (isClosed) return;

    emit(
      const AvailableOrdersLoaded(orders: [], pagination: {}, hasMore: false),
    );
  }

  void unblockAvailableOrdersFetch(BuildContext context) {
    _availableFetchBlocked = false;
    fetchAvailableOrders(context: context);
  }

  // ── Local list mutations ────────────────────────────────────────────────
  // These update the UI instantly with zero network cost.  Use them for
  // socket events whose payload tells us exactly which order changed.

  /// Remove a single order from the displayed list without any API call.
  /// Safe to call even if the order isn't in the current list.
  void removeOrderLocally(int orderId) {
    final current = state;
    if (current is! AvailableOrdersLoaded) return;

    final updated = current.orders.where((o) => o.id != orderId).toList();
    // Only re-emit if the list actually changed to avoid spurious rebuilds.
    if (updated.length == current.orders.length) return;
    if (isClosed) return;

    emit(
      AvailableOrdersLoaded(
        orders: updated,
        pagination: current.pagination,
        hasMore: current.hasMore,
        priceRange: current.priceRange,
      ),
    );
  }

  /// Prepend a new order to the displayed list without any API call.
  /// Skips if the order id is already present (idempotent).
  void addOrderLocally(OrderModel order) {
    final current = state;
    if (current is! AvailableOrdersLoaded) return;

    final alreadyPresent = current.orders.any((o) => o.id == order.id);
    if (alreadyPresent) return;

    final markedOrder = _markOrdersOutsidePriceRange([order]).first;
    if (isClosed) return;

    emit(
      AvailableOrdersLoaded(
        orders: [markedOrder, ...current.orders],
        pagination: current.pagination,
        hasMore: current.hasMore,
        priceRange: current.priceRange,
      ),
    );
  }

  // ── Network fetch ────────────────────────────────────────────────────────

  Future<void> fetchAvailableOrders({
    bool refresh = false,
    int limit = 20,
    double? minBudget,
    double? maxBudget,
    required BuildContext context,
    // true  → explicit user action (pull-to-refresh / filter apply)
    //         always re-fetches GPS so the list reflects the real position.
    // false → socket-triggered background reload
    //         reuses the cached GPS position to avoid the slow GPS round-trip.
    bool forceRefreshLocation = false,
  }) async {
    if (_availableFetchBlocked) {
      if (isClosed) return;

      emit(
        const AvailableOrdersLoaded(orders: [], pagination: {}, hasMore: false),
      );
      return;
    }
    if (refresh) {
      _availableOrdersPage = 1;
      if (isClosed) return;

      emit(const AvailableOrdersLoading());
    } else {
      if (_isLoadingMoreAvailable) return;
      _isLoadingMoreAvailable = true;

      final currentState = state;
      if (currentState is AvailableOrdersLoaded) {
        if (isClosed) return;

        emit(const AvailableOrdersLoading(isLoadingMore: true));
      } else {
        if (isClosed) return;

        emit(const AvailableOrdersLoading());
      }
    }

    try {
      final result = await _repository.getAvailableOrders(
        page: _availableOrdersPage,
        limit: limit,
        minBudget: minBudget,
        maxBudget: maxBudget,
        context: context,
        forceRefreshLocation: forceRefreshLocation,
      );

      final newOrders = result['orders'] as List<OrderModel>;
      final pagination = result['pagination'] as Map<String, dynamic>;
      final priceRange = result['priceRange'] as PriceRangeModel?;
      _priceRange = priceRange;
      dLog('Updated allowed order price range: '
          'allowed_min=${priceRange?.allowedMinOrderPrice}, '
          'allowed_max=${priceRange?.allowedMaxOrderPrice}');

      final currentPage = pagination['page'] as int;
      final totalPages = pagination['total_pages'] as int;
      final hasMore = currentPage < totalPages;

      List<OrderModel> finalOrders = _markOrdersOutsidePriceRange(newOrders);

      if (!refresh && state is AvailableOrdersLoaded) {
        final existingOrders = (state as AvailableOrdersLoaded).orders;
        finalOrders = [...existingOrders, ...finalOrders];
      }
      if (isClosed) return;

      emit(
        AvailableOrdersLoaded(
          orders: finalOrders,
          pagination: pagination,
          hasMore: hasMore,
          priceRange: priceRange,
        ),
      );

      _isLoadingMoreAvailable = false;
    } catch (e) {
      _isLoadingMoreAvailable = false;
      if (!isClosed) {
        emit(AvailableOrdersError(extractErrorMessage(e)));
      }
    }
  }

  Future<void> loadMoreAvailableOrders(BuildContext context) async {
    final currentState = state;
    if (currentState is AvailableOrdersLoaded && currentState.hasMore) {
      _availableOrdersPage++;
      // Pagination loads additional pages — location cache is fine here.
      await fetchAvailableOrders(context: context);
    }
  }

  // ============== Order History ==============
  Future<void> fetchOrderHistory({
    bool refresh = false,
    String filter = 'all',
    int limit = 20,
  }) async {
    if (refresh || filter != _currentHistoryFilter) {
      _historyPage = 1;
      _currentHistoryFilter = filter;
      if (isClosed) return;

      emit(const OrderHistoryLoading());
    } else {
      if (_isLoadingMoreHistory) return;
      _isLoadingMoreHistory = true;

      final currentState = state;
      if (currentState is OrderHistoryLoaded) {
        if (isClosed) return;

        emit(const OrderHistoryLoading(isLoadingMore: true));
      } else {
        if (isClosed) return;

        emit(const OrderHistoryLoading());
      }
    }

    try {
      final result = await _repository.getOrderHistory(
        page: _historyPage,
        limit: limit,
        filter: filter,
      );

      final newOrders = result['orders'] as List<OrderModel>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      final currentPage = pagination['page'] as int;
      final totalPages = pagination['total_pages'] as int;
      final hasMore = currentPage < totalPages;

      List<OrderModel> finalOrders = newOrders;

      if (!refresh &&
          filter == _currentHistoryFilter &&
          state is OrderHistoryLoaded) {
        final existingOrders = (state as OrderHistoryLoaded).orders;
        finalOrders = [...existingOrders, ...newOrders];
      }
      if (isClosed) return;

      emit(
        OrderHistoryLoaded(
          orders: finalOrders,
          pagination: pagination,
          hasMore: hasMore,
          currentFilter: filter,
        ),
      );

      _isLoadingMoreHistory = false;
    } catch (e) {
      _isLoadingMoreHistory = false;
      if (!isClosed) {
        emit(OrderHistoryError(extractErrorMessage(e)));
      }
    }
  }

  Future<void> loadMoreHistory() async {
    final currentState = state;
    if (currentState is OrderHistoryLoaded && currentState.hasMore) {
      _historyPage++;
      await fetchOrderHistory(filter: currentState.currentFilter);
    }
  }

  // ============== Submit Offer ==============
  Future<void> submitOffer({
    required int orderId,
    required int totalFee,
    required double distanceToPickup,
    required int timeToPickup,
    required int vehicleId,
  }) async {
    OrderModel? currentOrder;
    final currentState = state;
    if (currentState is OrderDetailsLoaded) {
      currentOrder = currentState.order;
    }
    if (isClosed) return;

    emit(SubmittingOffer());
    try {
      final proposal = await _repository.submitOffer(
        orderId: orderId,
        totalFee: totalFee,
        timeToPickup: timeToPickup,
        distanceToPickup: distanceToPickup,
        vehicleId: vehicleId,
      );

      _localProposalCache.add(orderId);
      if (isClosed) return;

      emit(OfferSubmitted(proposal, orderId));
    } catch (e) {
      if (isClosed) return;

      emit(OfferSubmitError(extractErrorMessage(e), order: currentOrder));
    }
  }

  // ============== Fixed-Fee Response ==============
  Future<void> respondToFixedFee({
    required int orderId,
    required String action, // 'ACCEPT' or 'REJECT'
  }) async {
    OrderModel? currentOrder;
    final currentState = state;
    if (currentState is OrderDetailsLoaded) {
      currentOrder = currentState.order;
    }
    if (isClosed) return;

    emit(RespondingToFixedFee(action));
    try {
      await _repository.respondToFixedFee(orderId: orderId, action: action);
      if (isClosed) return;

      emit(FixedFeeResponseSuccess(action));
    } catch (e) {
      if (isClosed) return;

      emit(FixedFeeResponseError(extractErrorMessage(e), order: currentOrder));
    }
  }

  // ============== Active Order ==============
  Future<void> fetchActiveOrder() async {
    if (isClosed) return;

    emit(ActiveOrderLoading());
    try {
      final orders = await _repository.getActiveOrder();
      _activeOrdersCount = orders.length;
      dLog('Active orders count: $_activeOrdersCount '
          '(max_orders_per_trip=${AppSettings.max_orders_per_trip})');

      if (orders.isEmpty) {
        if (isClosed) return;

        emit(NoActiveOrder());
      } else {
        if (isClosed) return;

        emit(ActiveOrderLoaded(orders));
      }
    } catch (e) {
      if (isClosed) return;

      emit(ActiveOrderError(extractErrorMessage(e)));
    }
  }

  // ============== Complete Delivery ==============
  Future<void> completeDelivery({
    required int orderId,
    required int courierId,
    required int customerId,
    required double actualPrice,
  }) async {
    OrderModel? currentOrder;
    final currentState = state;
    if (currentState is ActiveOrderLoaded) {
      currentOrder = currentState.order;
    }
    if (isClosed) return;

    emit(CompletingDelivery());
    try {
      final qrCode = await _repository.completeDelivery(
        orderId: orderId,
        actualPrice: actualPrice,
      );
      if (isClosed) return;

      emit(
        DeliveryCompleted(
          qrCode,
          orderId,
          actualPrice: actualPrice,
          courierId: courierId,
          customerId: customerId,
        ),
      );
    } catch (e) {
      if (isClosed) return;

      emit(DeliveryCompleteError(extractErrorMessage(e), order: currentOrder));
    }
  }

  // ============== Report High Price ==============
  Future<void> reportHighPrice({
    required int orderId,
    required double actualPrice,
  }) async {
    OrderModel? currentOrder;
    final currentState = state;
    if (currentState is ActiveOrderLoaded) {
      currentOrder = currentState.order;
    }
    if (isClosed) return;

    emit(ReportingHighPrice());
    try {
      await _repository.reportHighPrice(
        orderId: orderId,
        actualPrice: actualPrice,
      );
      if (isClosed) return;

      emit(HighPriceReported());
    } catch (e) {
      if (isClosed) return;

      emit(HighPriceReportError(extractErrorMessage(e), order: currentOrder));
    }
  }

  // ============== Cancel Order ==============
  Future<void> cancelOrderUnavailable({
    required int orderId,
    String note = 'Product Unavailable - المنتج غير متوفر',
  }) async {
    OrderModel? currentOrder;
    final currentState = state;
    if (currentState is ActiveOrderLoaded) {
      currentOrder = currentState.order;
    }
    if (isClosed) return;

    emit(CancelingOrder());
    try {
      final order = await _repository.cancelOrderUnavailable(
        orderId: orderId,
        note: note,
      );
      if (isClosed) return;

      emit(OrderCancelled(order));
    } catch (e) {
      if (isClosed) return;

      emit(OrderCancelError(extractErrorMessage(e), order: currentOrder));
    }
  }

  Future<void> cancelOrderOther({
    required int orderId,
    required String note,
  }) async {
    OrderModel? currentOrder;
    final currentState = state;
    if (currentState is ActiveOrderLoaded) {
      currentOrder = currentState.order;
    }
    if (isClosed) return;

    emit(CancelingOrder());
    try {
      final order = await _repository.cancelOrderOther(
        orderId: orderId,
        note: note,
      );
      if (isClosed) return;

      emit(OrderCancelled(order));
    } catch (e) {
      if (isClosed) return;

      emit(OrderCancelError(extractErrorMessage(e), order: currentOrder));
    }
  }

  // ============== Helper Methods ==============
  Future<bool> get hasActiveOrders async {
    final active = await _repository.getActiveOrder();
    return active.isNotEmpty;
  }

  Future<bool> aboveWalletLimit(BuildContext context) async {
    try {
      return await _repository.aboveWalletLimit(context);
    } catch (e) {
      return false;
    }
  }

  // ============== Mark Order Collected ==============
  Future<void> markOrderCollected({required int orderId}) async {
    OrderModel? currentOrder;
    final currentState = state;
    if (currentState is ActiveOrderLoaded) {
      currentOrder = currentState.order;
    }
    if (isClosed) return;

    emit(CollectingOrder());
    try {
      final order = await _repository.markOrderCollected(orderId: orderId);
      if (isClosed) return;

      emit(OrderCollected(order));
      fetchActiveOrder();
    } catch (e) {
      if (isClosed) return;

      emit(OrderCollectError(extractErrorMessage(e), order: currentOrder));
    }
  }

  Future<void> confirmWithOtpAndComplete({
    required int orderId,
    required double actualPrice,
    required String otp,
    required int courierId,
  }) async {
    try {
      if (isClosed) return;

      emit(ConfirmingWithOtp());

      await _repository.confirmWithOtp(
        orderId: orderId,
        actualPrice: actualPrice,
        otp: otp,
      );
      if (isClosed) return;

      emit(ConfirmWithOtpSuccess());
      if (isClosed) return;

      emit(FinalConfirmingDelivery());

      // await _repository.confirmDeliveryFinal(
      //   orderId: orderId,
      //   courierId: courierId,
      // );
      if (isClosed) return;

      emit(FinalConfirmSuccess());
    } catch (e) {
      if (isClosed) return;

      emit(ConfirmWithOtpError(extractErrorMessage(e)));
    }
  }

  // Reset pagination
  void resetPagination() {
    _availableOrdersPage = 1;
    _historyPage = 1;
    _isLoadingMoreAvailable = false;
    _isLoadingMoreHistory = false;
  }
}
