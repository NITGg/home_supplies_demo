import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/core/widgets/banners.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/order_card.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/orders_shimmers.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/utils/app_dynamic_settings.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/socket_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/layout/manager/home_cubit.dart';
import '../manager/orders_cubit.dart';
import '../manager/orders_states.dart';

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  final ScrollController _scrollController = ScrollController();

  // Socket subscriptions
  StreamSubscription? _newOrderSubscription;
  StreamSubscription? _orderCancelledSubscription;
  StreamSubscription? _offerAcceptedSubscription;
  StreamSubscription? _offerRejectedSubscription;
  StreamSubscription? _orderTakenSubscription;

  bool _isFilterExpanded = false;

  // ── Pull-to-refresh guard ────────────────────────────────────────────────
  bool _isRefreshing = false;

  static const double _absoluteMinBudget = 0;
  static const double _absoluteMaxBudget = 5000;

  RangeValues _currentRangeValues = const RangeValues(
    _absoluteMinBudget,
    _absoluteMaxBudget,
  );
  double? _appliedMinBudget;
  double? _appliedMaxBudget;

  // ── Offer-accepted debounce (existing) ──────────────────────────────────
  Timer? _offerAcceptedDebounceTimer;
  int? _lastOfferAcceptedOrderId;

  // ── General reload debounce ──────────────────────────────────────────────
  // Prevents multiple rapid socket events from kicking off multiple
  // concurrent API calls.  All socket-triggered reloads are coalesced into
  // a single request fired after the quiet period.
  static const _reloadDebounceDuration = Duration(milliseconds: 600);
  Timer? _reloadDebounceTimer;

  // ── Socket-triggered reload (debounced, no GPS re-fetch) ─────────────────
  // Use this for events that require a server round-trip but NOT a fresh GPS
  // fix (new order arrives, offer rejected).
  void _scheduleReload() {
    _reloadDebounceTimer?.cancel();
    _reloadDebounceTimer = Timer(_reloadDebounceDuration, () {
      if (!mounted) return;
      // forceRefreshLocation = false → reuse cached position, skip GPS wait.
      context.read<OrderCubit>().fetchAvailableOrders(
        context: context,
        refresh: true,
        minBudget: _appliedMinBudget,
        maxBudget: _appliedMaxBudget,
        forceRefreshLocation: false,
      );
    });
  }

  // ── Pull-to-refresh & button-triggered reload ────────────────────────────
  // Always forces a fresh GPS fix so the user gets results relative to their
  // current position.
  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    try {
      await _refreshActiveOrdersCount();
      if (!mounted) return;
      await context.read<OrderCubit>().fetchAvailableOrders(
        context: context,
        refresh: true,
        minBudget: _appliedMinBudget,
        maxBudget: _appliedMaxBudget,
        forceRefreshLocation: true, // explicit user action → fresh GPS
      );
      if (!mounted) return;
      await context
          .read<OrderCubit>()
          .stream
          .firstWhere(
              (s) => s is AvailableOrdersLoaded || s is AvailableOrdersError)
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () => AvailableOrdersError('timeout'),
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _setupSocketListeners();
    // Initial load — location cache is empty so a GPS fix will happen once.
    context.read<OrderCubit>().fetchAvailableOrders(
      context: context,
      refresh: true,
      forceRefreshLocation: true,
    );
    _refreshActiveOrdersCount();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cleanupSocketListeners();
    _offerAcceptedDebounceTimer?.cancel();
    _reloadDebounceTimer?.cancel();
    super.dispose();
  }

  // ================= SOCKET SETUP =================
  void _setupSocketListeners() {
    final socketService = SocketService();

    _newOrderSubscription = socketService.onNewOrderAvailable.listen((data) {
      if (mounted) _handleNewOrder(data);
    });

    _orderCancelledSubscription =
        socketService.onOrderCancelled.listen((data) {
          if (mounted) _handleOrderCancelled(data);
        });

    _offerAcceptedSubscription = socketService.onOfferAccepted.listen((data) {
      if (mounted) _handleOfferAccepted(data);
    });

    _offerRejectedSubscription = socketService.onOfferRejected.listen((data) {
      if (mounted) _handleOfferRejected(data);
    });

    _orderTakenSubscription = socketService.onOrderTaken.listen((data) {
      if (mounted) _handleOrderTaken(data);
    });
  }

  void _cleanupSocketListeners() {
    _newOrderSubscription?.cancel();
    _orderCancelledSubscription?.cancel();
    _offerAcceptedSubscription?.cancel();
    _offerRejectedSubscription?.cancel();
    _orderTakenSubscription?.cancel();
  }

  // ================= SOCKET EVENT HANDLERS =================

  /// A new order appeared on the server.
  /// We can't add it locally without the full model, so schedule a debounced
  /// API reload — but reuse the cached GPS position.
  void _handleNewOrder(Map<String, dynamic> data) => _scheduleReload();

  /// An order was cancelled by the customer.
  /// We know the exact orderId → remove it from the list instantly with zero
  /// network cost.  Fall back to a debounced reload only if the payload has
  /// no orderId.
  void _handleOrderCancelled(Map<String, dynamic> data) {
    final orderId = data['orderId'] as int?;
    if (orderId != null) {
      // Instant local removal — no GPS, no API call.
      context.read<OrderCubit>().removeOrderLocally(orderId);
    } else {
      _scheduleReload();
    }
  }

  /// Our offer was accepted — navigate to the active-order tab.
  void _handleOfferAccepted(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final orderId = data['orderId'] as int?;

    if (orderId != null) {
      _lastOfferAcceptedOrderId = orderId;
      _offerAcceptedDebounceTimer?.cancel();
      _offerAcceptedDebounceTimer = Timer(const Duration(seconds: 2), () {
        _lastOfferAcceptedOrderId = null;
      });
    }

    showSuccessBanner(context, l10n.offerAccepted);
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) context.read<HomeCubit>().changeTab(0);
    });

    // The accepted order is no longer "available" → remove it locally first
    // for instant feedback, then schedule a refresh to sync any other changes.
    if (orderId != null) {
      context.read<OrderCubit>().removeOrderLocally(orderId);
    }
    _scheduleReload();
  }

  /// Our offer was rejected — the order stays available; refresh to reflect
  /// any state changes from the server.
  void _handleOfferRejected(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    showInfoBanner(context, '${l10n.offerRejected}\n ${l10n.canSubmitAgain}');
    _scheduleReload();
  }

  /// Another courier took the order → remove it locally, no API call needed.
  /// Skip if it's the order we just won (handled by _handleOfferAccepted).
  void _handleOrderTaken(Map<String, dynamic> data) {
    final orderId = data['orderId'] as int?;
    if (orderId == null) return;
    if (orderId == _lastOfferAcceptedOrderId) return; // already handled

    // Instant local removal.
    context.read<OrderCubit>().removeOrderLocally(orderId);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      context.read<OrderCubit>().loadMoreAvailableOrders(context);
    }
  }

  void _applyFilters() {
    setState(() {
      _appliedMinBudget = _currentRangeValues.start > _absoluteMinBudget
          ? _currentRangeValues.start
          : null;
      _appliedMaxBudget = _currentRangeValues.end < _absoluteMaxBudget
          ? _currentRangeValues.end
          : null;
    });
    _loadOrders(); // user action → forceRefreshLocation = true inside
  }

  void _clearFilters() {
    setState(() {
      _currentRangeValues = const RangeValues(
        _absoluteMinBudget,
        _absoluteMaxBudget,
      );
      _appliedMinBudget = null;
      _appliedMaxBudget = null;
    });
    _loadOrders();
  }

  bool get _hasActiveFilters =>
      _appliedMinBudget != null || _appliedMaxBudget != null;

  /// Refreshes the cached active-orders count so we know whether the
  /// courier has hit [AppSettings.max_orders_per_trip].
  Future<void> _refreshActiveOrdersCount() async {
    await context.read<OrderCubit>().fetchActiveOrder();
    if (mounted) setState(() {});
  }

  bool get _hasReachedMaxActiveOrders {
    final max = AppSettings.max_orders_per_trip;
    if (max == null) return false;

    final count = context.read<OrderCubit>().activeOrdersCount;
    final reached = count >= max;
    if (reached) {
      dLog('Hiding available orders: active orders ($count) reached '
          'max_orders_per_trip ($max)');
    }
    return reached;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.kBackgroundColor,
      body: Column(
        children: [
          _buildFilterSection(l10n),
          Expanded(
            child: BlocConsumer<OrderCubit, OrderState>(
              buildWhen: (previous, current) {
                return current is AvailableOrdersLoading ||
                    current is AvailableOrdersLoaded ||
                    current is AvailableOrdersError;
              },
              listener: (context, state) {
                if (state is AvailableOrdersError) {
                  showErrorBanner(context, state.message);
                } else if (state is OfferSubmitted) {
                  showSuccessBanner(context, l10n.offerSubmittedSuccessfully);
                  // Remove the order we just bid on locally for instant UX,
                  // then schedule a background refresh.
                  context
                      .read<OrderCubit>()
                      .removeOrderLocally(state.orderId);
                  _scheduleReload();
                }
              },
              builder: (context, state) {
                // ── Full-screen shimmer only on the very first load ──────
                if (state is AvailableOrdersLoading &&
                    !state.isLoadingMore &&
                    !_isRefreshing) {
                  return OrderShimmers.availableOrdersListShimmer();
                }

                if (state is AvailableOrdersLoaded) {
                  if (state.orders.isEmpty) {
                    return _hasReachedMaxActiveOrders
                        ? _buildMaxActiveOrdersState(context)
                        : _buildEmptyState(context);
                  }

                  return RefreshIndicator(
                    onRefresh: _loadOrders,
                    color: AppColors.kPrimaryColor,
                    child: ListView.builder(
                      itemExtent: 145.0,   // Fixed height for OrderCard
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount:
                      state.orders.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= state.orders.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.kPrimaryColor,
                              ),
                            ),
                          );
                        }

                        final order = state.orders[index];
                        return OrderCardWidget(
                          order: order,
                          isDimmed: _hasReachedMaxActiveOrders,
                          onTap: () async {
                            if (order.isOutOfPriceRange) {
                              final maxValue = context
                                  .read<OrderCubit>()
                                  .priceRange
                                  ?.allowedMaxOrderPrice
                                  .toStringAsFixed(0);
                              showInfoBanner(
                                context,
                                l10n.orderValueLimitReachedMessage(
                                    maxValue ?? ''),
                              );
                              return;
                            }

                            if (_hasReachedMaxActiveOrders) {
                              showInfoBanner(
                                context,
                                l10n.maxActiveOrdersReachedMessage,
                              );
                              return;
                            }

                            final result = await context.push(
                              '/orders/details',
                              extra: order,
                            );
                            if (!mounted) return;

                            if (result == true) {
                              _loadOrders();
                            } else if (result == 'fixed_fee_accepted') {
                              if (!context.mounted) return;
                              context.read<HomeCubit>().changeTab(0);
                            }
                          },
                        );
                      },
                    ),
                  );
                }

                if (state is AvailableOrdersError) {
                  return _buildEmptyState(context, isError: true);
                }

                // Catch-all: AvailableOrdersInitial or any unhandled state
                return OrderShimmers.availableOrdersListShimmer();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: _isFilterExpanded ? Colors.white : AppColors.kBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isFilterExpanded = !_isFilterExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    color: _hasActiveFilters
                        ? AppColors.kPrimaryColor
                        : Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.filterByBudget,
                    style: AppTextStyles.medium18.copyWith(
                      color: _hasActiveFilters
                          ? AppColors.kPrimaryColor
                          : Colors.grey.shade800,
                      fontSize: 14,
                    ),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_appliedMinBudget?.toStringAsFixed(0) ?? _absoluteMinBudget.toStringAsFixed(0)} - ${_appliedMaxBudget?.toStringAsFixed(0) ?? _absoluteMaxBudget.toStringAsFixed(0)}',
                        style: AppTextStyles.medium18.copyWith(
                          color: AppColors.kPrimaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    _isFilterExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isFilterExpanded
                ? Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Range display
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _currentRangeValues.start.toStringAsFixed(0),
                          style: AppTextStyles.medium18.copyWith(
                            fontSize: 16,
                            color: AppColors.kPrimaryColor,
                          ),
                        ),
                        Text(
                          _currentRangeValues.end.toStringAsFixed(0),
                          style: AppTextStyles.medium18.copyWith(
                            fontSize: 16,
                            color: AppColors.kPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Range Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.kPrimaryColor,
                      inactiveTrackColor: Colors.grey.shade300,
                      thumbColor: AppColors.kPrimaryColor,
                      overlayColor:
                      AppColors.kPrimaryColor.withOpacity(0.2),
                      valueIndicatorColor: AppColors.kPrimaryColor,
                      valueIndicatorTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 20,
                      ),
                    ),
                    child: RangeSlider(
                      values: _currentRangeValues,
                      min: _absoluteMinBudget,
                      max: _absoluteMaxBudget,
                      divisions: 100,
                      labels: RangeLabels(
                        _currentRangeValues.start.toStringAsFixed(0),
                        _currentRangeValues.end.toStringAsFixed(0),
                      ),
                      onChanged: (RangeValues values) {
                        setState(() {
                          _currentRangeValues = values;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Min/Max labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.minBudget,
                          style: AppTextStyles.regular14.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          l10n.maxBudget,
                          style: AppTextStyles.regular14.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearFilters,
                          style: OutlinedButton.styleFrom(
                            side:
                            BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            l10n.clear,
                            style: AppTextStyles.medium18.copyWith(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _applyFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.kPrimaryColor,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            l10n.apply,
                            style: AppTextStyles.medium18.copyWith(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMaxActiveOrdersState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppColors.kPrimaryColor,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.expand(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.kSecondaryLightColor.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: AppColors.kPrimaryColor.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.maxActiveOrdersReachedTitle,
                      style: AppTextStyles.bold18.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        l10n.maxActiveOrdersReachedMessage,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey.shade500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {bool isError = false}) {
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppColors.kPrimaryColor,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.expand(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.kSecondaryLightColor.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isError
                            ? Icons.error_outline
                            : Icons.shopping_bag_outlined,
                        size: 80,
                        color: AppColors.kPrimaryColor.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isError ? l10n.error : l10n.noAvailableOrders,
                      style: AppTextStyles.bold18.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        isError ? '' : l10n.checkBackLater,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey.shade500,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: _loadOrders,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retry),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.kPrimaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}