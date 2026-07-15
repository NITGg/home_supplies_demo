// courier

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:tawreedat_courier/core/widgets/banners.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/empty_state.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/live_route_map.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/orders_shimmers.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/biometric_auth_service.dart';
import '../../../../core/utils/keep_alive_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/phone_dialer.dart';
import '../../../../core/utils/socket_service.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/image_with_fallback.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/config/chat_injection.dart';
import '../../../home/layout/manager/home_cubit.dart';
import '../../data/models/orders_model.dart';
import '../../manager/orders_cubit.dart';
import '../../manager/orders_states.dart';
import '../widgets/order_bottom_sheets.dart';
import '../widgets/supplier_review_bottom_sheet.dart';
import 'active_order_helpers.dart';
import 'active_order_sort.dart';
import 'order_switch.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// Holds pre-computed (original, afterDiscount) pairs for every money field
/// shown on the active-order screen.
typedef _Prices = ({
double budgetOriginal,
double budgetAfterDiscount,
double costOriginal,
double costAfterDiscount,
double feeOriginal,
double feeAfterDiscount,
double platformFee,
double subtotalCatalog,
double subtotalRegular,
});

// ─────────────────────────────────────────────────────────────────────────────

class ActiveOrderScreen extends StatefulWidget {
  const ActiveOrderScreen({super.key});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  final TextEditingController _actualPriceController = TextEditingController();
  StreamSubscription? _priceReportResponseSubscription;
  StreamSubscription? _orderCancelledSubscription;

  int? _currentActiveOrderId;

  List<OrderModel>? _lastKnownOrders;
  int _selectedOrderIndex = 0;

  int? _trackingForOrderId;
  Timer? _locationUpdateTimer;
  Position? _lastEmittedPosition;

  // ── Convenience getter ────────────────────────────────────────────────────

  OrderModel? get _displayedOrder {
    if (_lastKnownOrders == null || _lastKnownOrders!.isEmpty) return null;
    return _lastKnownOrders![_selectedOrderIndex.clamp(0, _lastKnownOrders!.length - 1)];
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadActiveOrder();
    _setupSocketListeners();
    _seedInitialPosition();
  }

  @override
  void dispose() {
    _actualPriceController.dispose();
    _cleanupSocketListeners();
    _stopLocationUpdates();
    super.dispose();
  }

  // ── Seed courier position before any order is collected ───────────────────

  Future<void> _seedInitialPosition() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;

      setState(() {
        _lastEmittedPosition = position;
        if (_lastKnownOrders != null && _lastKnownOrders!.length > 1) {
          _lastKnownOrders = sortOrdersByNextWaypoint(_lastKnownOrders!, position);
          _selectedOrderIndex = _selectedOrderIndex.clamp(0, _lastKnownOrders!.length - 1);
        }
      });
    } catch (_) {
      // Non-fatal — distances won't show until tracking starts normally.
    }
  }

  // ── Location tracking ─────────────────────────────────────────────────────

  void _startLocationUpdates(int orderId) {
    if (_trackingForOrderId == orderId && (_locationUpdateTimer?.isActive ?? false)) return;

    _trackingForOrderId = orderId;
    _locationUpdateTimer?.cancel();
    KeepAliveService.startLocationTracking(orderId);

    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

        if (_lastEmittedPosition != null) {
          final distance = Geolocator.distanceBetween(
            _lastEmittedPosition!.latitude,
            _lastEmittedPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          if (distance < 10) return;
        }

        _lastEmittedPosition = position;
        await ApiClient.instance.dio.patch(
          '/order/$orderId/location',
          data: {'lat': position.latitude, 'lng': position.longitude},
        );
        dLog('📍 [ActiveOrder] PATCH location order=$orderId ${position.latitude}, ${position.longitude}');
      } catch (e) {
        dLog('⚠️ [ActiveOrder] Location update failed: $e');
      }
    });
  }

  void _stopLocationUpdates() {
    _trackingForOrderId = null;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    KeepAliveService.stopLocationTracking();
  }

  void _clearPosition() => _lastEmittedPosition = null;

  // ── Socket ────────────────────────────────────────────────────────────────

  void _setupSocketListeners() {
    _priceReportResponseSubscription = SocketService().onPriceReportResponse.listen(
          (data) { if (mounted) _handlePriceReportResponse(data); },
    );
    _orderCancelledSubscription = SocketService().onOrderCancelled.listen(
          (data) { if (mounted) _handleOrderCancelled(data); },
    );
  }

  void _cleanupSocketListeners() {
    _priceReportResponseSubscription?.cancel();
    _orderCancelledSubscription?.cancel();
  }

  void _handlePriceReportResponse(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final approved  = data['approved']  as bool?;
    final newBudget = data['newBudget'] as String?;
    final orderId   = data['orderId']   as int?;

    if (orderId == null || orderId != _currentActiveOrderId) return;

    if (approved == true) {
      final budgetLine = newBudget != null ? '\n${l10n.newBudget}: $newBudget ${l10n.egp}' : '';
      showSuccessBanner(context, '${l10n.budgetApproved}$budgetLine');
    } else {
      showInfoBanner(context, l10n.budgetNotApproved);
    }
    _loadActiveOrder();
  }

  void _handleOrderCancelled(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final cancelledOrderId = data['orderId'] as int?;
    final orders = _lastKnownOrders;

    if (cancelledOrderId == null || orders == null) return;
    if (!orders.any((o) => o.id == cancelledOrderId)) return;

    _stopLocationUpdates();
    _clearPosition();
    showInfoBanner(context, l10n.orderCancelled);

    final remaining = orders.where((o) => o.id != cancelledOrderId).toList();
    if (remaining.isEmpty) {
      _lastKnownOrders = null;
      _selectedOrderIndex = 0;
      _currentActiveOrderId = null;
      _loadActiveOrder();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) context.read<HomeCubit>().changeTab(1);
      });
    } else {
      setState(() {
        _lastKnownOrders = remaining;
        _selectedOrderIndex = _selectedOrderIndex.clamp(0, remaining.length - 1);
        _currentActiveOrderId = remaining[_selectedOrderIndex].id;
      });
    }
  }

  void _loadActiveOrder() => context.read<OrderCubit>().fetchActiveOrder();

  // ── Maps ──────────────────────────────────────────────────────────────────

  Future<void> _openInMaps(String lat, String lng, String shortLabel) async {
    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    final geoUrl= 'geo:$lat,$lng?q=$lat,$lng($shortLabel)';
    final appleMapsUrl = 'maps://?saddr=Current%20Location&daddr=$lat,$lng&dirflg=d';

    try {
      if (Platform.isAndroid) {
        if (!await launchUrlString(geoUrl, mode: LaunchMode.externalApplication)) {
          await launchUrlString(googleMapsUrl, mode: LaunchMode.externalApplication);
        }
      } else if (Platform.isIOS) {
        if (!await launchUrlString(appleMapsUrl, mode: LaunchMode.externalApplication)) {
          await launchUrlString(googleMapsUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      await launchUrlString(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  // ── Scaffold ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.kBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async => _loadActiveOrder(),
        color: AppColors.kPrimaryColor,
        child: BlocConsumer<OrderCubit, OrderState>(
          listener: (context, state) => _handleStateChanges(context, state, l10n),
          builder:  (context, state) => _buildBody(context, state, l10n),
        ),
      ),
    );
  }

  // ── Body builder ──────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, OrderState state, AppLocalizations l10n) {
    // Full-screen loading — no cached data yet.
    if (state is ActiveOrderLoading && _lastKnownOrders == null) {
      return OrderShimmers.activeOrderShimmer();
    }

    // Spinner overlay while an operation is in-flight; keep last order visible.
    if (state is CompletingDelivery || state is CollectingOrder) {
      final order = _displayedOrder;
      return order != null
          ? Stack(children: [_buildOrderWithToggle(context, order), const LoadingScreen(isOne: true)])
          : const LoadingScreen(isOne: true);
    }

    // No active order — clear cache, tab-switch handled in listener.
    if (state is NoActiveOrder) {
      _currentActiveOrderId = null;
      _lastKnownOrders      = null;
      _selectedOrderIndex   = 0;
      return _buildNoActiveOrderState(l10n);
    }

    // Happy path — sort by nearest waypoint and cache.
    if (state is ActiveOrderLoaded) {
      _lastKnownOrders = sortOrdersByNextWaypoint(state.orders, _lastEmittedPosition);
      _selectedOrderIndex = _selectedOrderIndex.clamp(0, _lastKnownOrders!.length - 1);
      final order = _lastKnownOrders![_selectedOrderIndex];
      _currentActiveOrderId = order.id;

      final serverPrice = order.actualPrice;
      if (serverPrice != null && serverPrice.isNotEmpty && serverPrice != '0') {
        _actualPriceController.text = serverPrice;
      }

      order.collectedAt != null ? _startLocationUpdates(order.id) : _stopLocationUpdates();
      return _buildOrderWithToggle(context, order);
    }

    // Error states — prefer embedded order then fall back to cache.
    final embeddedOrder = switch (state) {
      ActiveOrderError      s => s.order,
      DeliveryCompleteError s => s.order,
      HighPriceReportError  s => s.order,
      OrderCancelError      s => s.order,
      OrderCollectError     s => s.order,
      _                       => null,
    };

    final orderToShow = embeddedOrder ?? _displayedOrder;
    if (orderToShow != null) {
      _currentActiveOrderId = orderToShow.id;
      return _buildOrderWithToggle(context, orderToShow);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [OrderShimmers.activeOrderShimmer()],
    );
  }

  // ── State change listener ─────────────────────────────────────────────────

  void _handleStateChanges(BuildContext context, OrderState state, AppLocalizations l10n) {
    if (state is OrderCollected) {
      showSuccessBanner(context, l10n.pickupConfirmed);
      if (state.order.isCatalogPurchase) _showSupplierReviewSheet(state.order.id);
      _loadActiveOrder();
    } else if (state is OrderCollectError) {
      showErrorBanner(context, state.message);
      setState(() {});
    } else if (state is OrderCancelled) {
      _stopLocationUpdates();

      final cancelledId = state.order.id;
      final remaining = (_lastKnownOrders ?? [])
          .where((o) => o.id != cancelledId)
          .toList();

      // Clear cache first so ActiveOrderLoading shows shimmer, not stale data
      _lastKnownOrders = remaining.isEmpty ? null : remaining;
      _selectedOrderIndex =
      remaining.isEmpty ? 0 : _selectedOrderIndex.clamp(0, remaining.length - 1);
      _currentActiveOrderId =
      remaining.isEmpty ? null : remaining[_selectedOrderIndex].id;

      showInfoBanner(context, l10n.orderCancelled);
      _loadActiveOrder();
    } else if (state is HighPriceReported) {
      showSuccessBanner(context, l10n.done);
      _loadActiveOrder();
    } else if (state is ActiveOrderError) {
      showErrorBanner(context, state.message);
    } else if (state is DeliveryCompleted) {
      _handleDeliveryCompleted(state);
    } else if (state is DeliveryCompleteError) {
      showErrorBanner(context, state.message);
    } else if (state is NoActiveOrder) {
      _stopLocationUpdates();
      _currentActiveOrderId = null;
      _lastKnownOrders      = null;
      _selectedOrderIndex   = 0;
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (context.mounted) context.read<HomeCubit>().changeTab(1);
      });
    }
  }

  void _handleDeliveryCompleted(DeliveryCompleted state) {
    _stopLocationUpdates();
    _clearPosition();

    List<OrderModel> remaining = [];
    if (_lastKnownOrders != null) {
      remaining = _lastKnownOrders!.where((o) => o.id != state.orderId).toList();
      if (remaining.isNotEmpty) {
        _lastKnownOrders = remaining;
        _selectedOrderIndex = _selectedOrderIndex.clamp(0, (remaining.length - 1).clamp(0, 99));
      }
      // Single-order path: keep cache intact until after push so the builder
      // never sees null + DeliveryCompleted simultaneously.
    }

    context.push('/orders/qr-code', extra: {
      'qrCodeModel' : state.qrCode,
      'orderId'     : state.orderId,
      'actualPrice' : state.actualPrice,
      'courierId'   : state.courierId,
      'customerId'  : state.customerId,
    }).then((_) {
      if (!mounted) return;
      if (remaining.isEmpty) {
        _lastKnownOrders      = null;
        _currentActiveOrderId = null;
        _selectedOrderIndex   = 0;
      }
      if (context.mounted) _loadActiveOrder();
    });
  }

  // ── Order + drawer wrapper ────────────────────────────────────────────────

  Widget _buildOrderWithToggle(BuildContext context, OrderModel order) {
    final orders = _lastKnownOrders;
    if (orders == null || orders.length <= 1) {
      return _buildActiveOrder(context, order, bottomPadding: 0);
    }

    return Stack(
      children: [
        // Extra bottom padding so the last card is never hidden behind
        // the collapsed drawer (handle + summary row ≈ 68 px).
        _buildActiveOrder(context, order, bottomPadding: 76),

        // Fills the entire Stack so its scrim can cover the content area.
        Positioned.fill(
          child: OrderSwitcherDrawer(
            orders: orders,
            selectedIndex: _selectedOrderIndex,
            courierPosition: _lastEmittedPosition,
            onOrderSelected: (index) {
              setState(() {
                _selectedOrderIndex = index;
                _actualPriceController.clear();
              });
              final selected = orders[index];
              _currentActiveOrderId = selected.id;
              selected.collectedAt != null
                  ? _startLocationUpdates(selected.id)
                  : _stopLocationUpdates();
            },
          ),
        ),
      ],
    );
  }

  // ── Price computation ─────────────────────────────────────────────────────

  _Prices _computePrices(OrderModel order) {
    final hasActualPrice = order.actualPrice != null && order.actualPrice != '0';
    final rawPrice = hasActualPrice ? order.actualPrice  : order.budget;
    final rawCost  = hasActualPrice ? order.costPrice    : order.budget;

    final hasProductDiscount = order.hasProductsOnlyDiscount || order.hasOrderTotalDiscount;
    final hasFeeDiscount     = order.hasDeliveryFeeDiscount  || order.hasOrderTotalDiscount;

    ({double original, double afterDiscount}) passthrough(String? val) {
      final v = double.tryParse(val ?? '0') ?? 0;
      return (original: v, afterDiscount: v);
    }

    final budget   = hasProductDiscount ? computeDiscounted(rawPrice, order.discountAmount) : passthrough(rawPrice);
    final cost     = hasProductDiscount ? computeDiscounted(rawCost,  order.discountAmount) : passthrough(rawCost);
    final fee      = hasFeeDiscount     ? computeDiscounted(order.courierFee, order.discountAmount) : passthrough(order.courierFee);
    final platform = double.tryParse(order.platformFee ?? '0') ?? 0;

    return (
    budgetOriginal:      budget.original,
    budgetAfterDiscount: budget.afterDiscount,
    costOriginal:        cost.original,
    costAfterDiscount:   cost.afterDiscount,
    feeOriginal:         fee.original,
    feeAfterDiscount:    fee.afterDiscount,
    platformFee:         platform,
    subtotalCatalog:     fee.afterDiscount + cost.afterDiscount   + platform,
    subtotalRegular:     fee.afterDiscount + budget.afterDiscount + platform,
    );
  }

  // ── Top-level layout ──────────────────────────────────────────────────────

  Widget _buildNoActiveOrderState(AppLocalizations l10n) => AppEmptyState(
    icon: Icons.inventory_2_outlined,
    title: l10n.noActiveOrder,
    subtitle: l10n.noActiveDeliveries,
  );

  Widget _buildActiveOrder(BuildContext context, OrderModel order, {double bottomPadding = 0}) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBanner(l10n, order),
          const SizedBox(height: 12),
          _buildProductSection(context, l10n, order),
          const SizedBox(height: 12),
          if (order.customer != null) _buildCustomerSection(context, l10n, order),
          const SizedBox(height: 12),
          _buildOrderInfoSection(context, l10n, order),
          const SizedBox(height: 12),
          _buildRouteSection(context, l10n, order),
          const SizedBox(height: 12),
          _buildOrderTimeline(context, l10n, order),
          const SizedBox(height: 12),
          _buildCancelOrderSection(context, l10n, order),
          const SizedBox(height: 12),
          if (order.collectedAt == null && !order.isCatalogPurchase && order.budget != '0.01')
            _buildReportBudgetSection(context, l10n, order),
          const SizedBox(height: 12),
          _buildPickupConfirmationSection(context, l10n, order),
          const SizedBox(height: 12),
          _buildCompleteDeliverySection(context, l10n, order),
          SizedBox(height: 24 + bottomPadding),
        ],
      ),
    );
  }

  // ── Pickup confirmation ───────────────────────────────────────────────────

  Future<void> _confirmPickup(OrderModel order) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(Icons.storefront_outlined, size: 40, color: Colors.green.shade700),
            ),
            const SizedBox(height: 16),
            Text(l10n.confirmPickup, style: AppTextStyles.bold18),
            const SizedBox(height: 8),
            Text(
              l10n.confirmPickupMessage,
              style: AppTextStyles.regular14.copyWith(color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: AppTextStyles.bold16.copyWith(color: Colors.grey.shade700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.iPickedItUp,
                      style: AppTextStyles.bold16.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      context.read<OrderCubit>().markOrderCollected(orderId: order.id);
    }
  }

  void _showSupplierReviewSheet(int orderId) {
    dLog('showing supplier review sheet for order $orderId');
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupplierReviewBottomSheet(orderId: orderId),
    );
  }

  Widget _buildPickupConfirmationSection(
      BuildContext context,
      AppLocalizations l10n,
      OrderModel order,
      ) {
    if (order.collectedAt != null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.check_circle_outline, l10n.confirmPickup, Colors.orange.shade700),
          const SizedBox(height: 8),
          Text(
            l10n.confirmPickupMessage,
            style: AppTextStyles.regular14.copyWith(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 12),
          AppCustomButton(
            onPressed: () => _confirmPickup(order),
            text: l10n.iPickedItUp,
            isSecondary: true,
          ),
        ],
      ),
    );
  }

  // ── Status banner ─────────────────────────────────────────────────────────

  Widget _buildStatusBanner(AppLocalizations l10n, OrderModel order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.kPrimaryColor, AppColors.kSecondaryColor.withOpacity(0.8)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ClipOval(
              child: Lottie.asset('assets/animation_json/Delivery.json', width: 120, height: 120),
            ),
            const SizedBox(height: 12),
            Text(l10n.deliveryInProgress, style: AppTextStyles.bold25.copyWith(color: Colors.white)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                order.orderNumber,
                style: AppTextStyles.medium18.copyWith(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Product section ───────────────────────────────────────────────────────

  Widget _buildProductSection(BuildContext context, AppLocalizations l10n, OrderModel order) {
    final prices         = _computePrices(order);
    final discountHints  = buildDiscountHints(order, l10n);
    final hasAnyDiscount = discountHints.isNotEmpty;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(order.budget == '0.01' ? l10n.shipping : l10n.productDetails, style: AppTextStyles.bold16),
          const SizedBox(height: 12),
          // Catalog items list
          if (order.isCatalogPurchase)
            ...order.orderItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImageWithIconFallback(
                      imageUrl: item.product.images.isNotEmpty ? item.product.images.first : '',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.product.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${l10n.quantity}: ${item.quantity}'),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          const SizedBox(height: 12),
          // Product image + pricing
          Row(
            children: [
              if (!order.isCatalogPurchase)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ImageWithIconFallback(
                    imageUrl: order.productImage,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    iconSize: 40,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.productDescription ?? '', style: AppTextStyles.bold14),
                    const SizedBox(height: 8),
                    // Pay-to-supplier row (catalog + cash only)
                    if (order.paymentMethod == 'CASH' && order.isCatalogPurchase)
                      _buildInfoRowWidget(
                        context, l10n.payToSupplier, Icons.store,
                        child: DiscountedValue(
                          original: double.parse(order.costPrice ?? '0'),
                          afterDiscount: double.parse(order.costPrice ?? '0'),
                          currency: l10n.egp,
                        ),
                      ),
                    // Budget / price row
                    if (
                        !order.isCatalogPurchase)
                      if (prices.budgetOriginal > 0.01)
                        _buildInfoRowWidget(
                          context,
                          order.isCatalogPurchase ? l10n.price : l10n.budget,
                          Icons.account_balance_wallet,
                          child: DiscountedValue(
                            original: prices.budgetOriginal,
                            afterDiscount: prices.budgetAfterDiscount,
                            currency: l10n.egp,
                          ),
                        ),
                    // Delivery fee
                    _buildInfoRowWidget(
                      context, l10n.totalFee, Icons.motorcycle,
                      child: DiscountedValue(
                        original: prices.feeOriginal,
                        afterDiscount: prices.feeAfterDiscount,
                        currency: l10n.egp,
                      ),
                    ),
                    // Platform / service fee
                    _buildInfoRowWidget(
                      context, l10n.serviceFee, Icons.app_shortcut,
                      child: DiscountedValue(
                        original: prices.platformFee,
                        afterDiscount: prices.platformFee,
                        currency: l10n.egp,
                      ),
                    ),
                    if (order.hasDeliveryFeeDiscount || order.hasOrderTotalDiscount) ...[
                      const SizedBox(height: 4),
                      ...discountHints,
                      const SizedBox(height: 4),
                    ],
                    // Subtotal (collect from customer)
                    if (order.paymentMethod == 'CASH')
                      _buildInfoRowWidget(
                        context,
                        '${l10n.subtotal} (${l10n.collectFromCustomer})',
                        Icons.payments_rounded,
                        child: DiscountedValue(
                          original: order.isCatalogPurchase ? prices.subtotalCatalog : prices.subtotalRegular,
                          afterDiscount: order.isCatalogPurchase ? prices.subtotalCatalog : prices.subtotalRegular,
                          currency: l10n.egp,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Customer section ──────────────────────────────────────────────────────

  Widget _buildCustomerSection(BuildContext context, AppLocalizations l10n, OrderModel order) {
    final customer = order.customer!;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.customerInformation, style: AppTextStyles.bold16),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.kSecondaryLightColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.kSecondaryLightColor,
                  child: customer.personalPhoto != null
                      ? ClipOval(
                    child: ImageWithIconFallback(
                      imageUrl: customer.personalPhoto,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  )
                      : const Icon(Icons.person, color: AppColors.kPrimaryColor, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.fullName, style: AppTextStyles.bold16),
                      if (customer.phone != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          customer.phone!,
                          textDirection: ui.TextDirection.ltr,
                          style: AppTextStyles.regular14.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                if (customer.phone != null)
                  _iconActionButton(
                    icon: Icons.phone,
                    gradient: [AppColors.kPrimaryColor, AppColors.kPrimaryColor.withOpacity(0.8)],
                    onPressed: () => openPhoneApp(customer.phone ?? ''),
                  ),
                const SizedBox(width: 8),
                _iconActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  gradient: [Colors.orange.shade600, Colors.orange.shade400],
                  onPressed: () async {
                    if (!context.mounted) return;
                    ChatNavigator.openChatWithUser(
                      context,
                      targetUserId: customer.id,
                      orderId: order.id,
                      chatTitle: customer.fullName,
                      chatAvatarUrl: customer.personalPhoto,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Order info section ────────────────────────────────────────────────────

  Widget _buildOrderInfoSection(BuildContext context, AppLocalizations l10n, OrderModel order) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.orderInformation, style: AppTextStyles.bold16),
          const SizedBox(height: 16),
          _buildInfoRow(context, l10n.paymentMethod, order.paymentMethod, Icons.payment),
          _buildInfoRow(context, l10n.status, _getStatusText(context, order.status), Icons.info_outline),
          _buildInfoRow(
            context,
            l10n.created,
            DateFormat('MMM dd, yyyy - hh:mm a').format(order.createdAt),
            Icons.calendar_today,
          ),
        ],
      ),
    );
  }

  // ── Route section ─────────────────────────────────────────────────────────

  Widget _buildRouteSection(BuildContext context, AppLocalizations l10n, OrderModel order) {
    final isArabic = l10n.localeName == 'ar';

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.distanceM != '0')
            _infoChipRow(
              label: l10n.deliveryRoute,
              icon: Icons.route_rounded,
              value: _formatMeters(double.tryParse(order.distanceM ?? '0') ?? 0, l10n),
              color: AppColors.kPrimaryColor,
            ),
          const SizedBox(height: 12),
          LiveRouteMapWidget(
            pickupLat:  double.tryParse(order.pickupLat  ?? '0') ?? 0,
            pickupLng:  double.tryParse(order.pickupLong ?? '0') ?? 0,
            deliveryLat: double.tryParse(order.deliveryLat  ?? '0') ?? 0,
            deliveryLng: double.tryParse(order.deliveryLong ?? '0') ?? 0,
            locationUpdateInterval: const Duration(seconds: 15),
            routeRefetchThresholdMeters: 100,
          ),
          const SizedBox(height: 12),
          _buildLocationDetail(
            context: context,
            icon: Icons.store_outlined,
            title: l10n.pickupLocation,
            area: isArabic ? order.pickupArea!.nameAr : order.pickupArea!.name,
            address: order.pickupAddressDescription,
            color: AppColors.kPrimaryColor,
            lat: order.pickupLat,
            lng: order.pickupLong,
          ),
          _buildRouteDivider(),
          _buildLocationDetail(
            context: context,
            icon: Icons.location_on,
            title: l10n.deliveryLocation,
            area: isArabic ? order.deliveryArea!.nameAr : order.deliveryArea!.name,
            address: order.deliveryAddressDescription,
            color: Colors.green,
            lat: order.deliveryLat,
            lng: order.deliveryLong,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Column(
            children: List.generate(
              4,
                  (_) => Container(
                width: 2,
                height: 6,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.kPrimaryColor.withOpacity(0.3),
                  Colors.green.withOpacity(0.3),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_downward, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  // ── Timeline ──────────────────────────────────────────────────────────────

  Widget _buildOrderTimeline(BuildContext context, AppLocalizations l10n, OrderModel order) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.timeline, style: AppTextStyles.bold16),
          const SizedBox(height: 12),
          _buildTimelineItem(
            context,
            l10n.orderCreated,
            DateFormat('MMM dd, hh:mm a').format(order.createdAt),
            true,
          ),
          if (order.offerAcceptedAt != null)
            _buildTimelineItem(
              context,
              l10n.offerAccepted,
              DateFormat('MMM dd, hh:mm a').format(order.offerAcceptedAt!),
              true,
            ),
          if (order.collectedAt != null)
            _buildTimelineItem(
              context,
              l10n.iPickedItUp,
              DateFormat('MMM dd, hh:mm a').format(order.collectedAt!),
              true,
            ),
        ],
      ),
    );
  }

  // ── Cancel section ────────────────────────────────────────────────────────

  Widget _buildCancelOrderSection(BuildContext context, AppLocalizations l10n, OrderModel order) {
    final isRegularUncollected =
        order.collectedAt == null && !order.isCatalogPurchase && order.budget != '0.01';

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.cancel_outlined, l10n.cancelOrder, Colors.red.shade700),
          const SizedBox(height: 12),
          if (isRegularUncollected) ...[
            AppCustomButton(
              onPressed: () => _showCancelDialog(context, order, isUnavailable: true),
              text: l10n.productUnAvailable,
              isSecondary: true,
            ),
            const SizedBox(height: 8),
          ],
          AppCustomButton(
            onPressed: () => _showCancelDialog(context, order, isUnavailable: false),
            text: isRegularUncollected ? l10n.otherReason : l10n.cancelOrder,
            isDelete: true,
          ),
        ],
      ),
    );
  }

  // ── Report budget section ─────────────────────────────────────────────────

  Widget _buildReportBudgetSection(BuildContext context, AppLocalizations l10n, OrderModel order) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.payments_outlined, l10n.budgetNotEnough, Colors.orange.shade700),
          const SizedBox(height: 12),
          AppCustomButton(
            onPressed: () => _showReportHighPriceDialog(context, order),
            text: l10n.askCustomer,
            isSecondary: true,
          ),
        ],
      ),
    );
  }

  // ── Complete delivery section ─────────────────────────────────────────────

  Widget _buildCompleteDeliverySection(BuildContext context, AppLocalizations l10n, OrderModel order) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.qr_code_2, l10n.completeDelivery, AppColors.kPrimaryColor),
          if (!order.isCatalogPurchase && _actualPriceController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              l10n.actualProductPrice,
              '${_actualPriceController.text} ${l10n.egp}',
              Icons.payments_rounded,
            ),
          ],
          const SizedBox(height: 12),
          AppCustomButton(
            enabled: order.collectedAt != null,
            onPressed: () => _completeDelivery(order),
            text: l10n.generateQrCode,
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _iconActionButton({
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  Widget _infoChipRow({
    required String label,
    required IconData icon,
    required String value,
    String? duration,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.regular14.copyWith(fontSize: 10, color: color.withOpacity(0.7)),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(value, style: AppTextStyles.bold14.copyWith(fontSize: 13, color: color)),
              if (duration != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 1,
                  height: 12,
                  color: color.withOpacity(0.3),
                ),
                Icon(Icons.access_time_rounded, size: 12, color: color.withOpacity(0.8)),
                const SizedBox(width: 3),
                Text(duration, style: AppTextStyles.bold14.copyWith(fontSize: 13, color: color.withOpacity(0.85))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDetail({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String area,
    required String address,
    required Color color,
    String? lat,
    String? lng,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: (lat != null && lng != null)
          ? () => _openInMaps(lat, lng, address.split(',').first)
          : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bold14.copyWith(color: color)),
                  const SizedBox(height: 6),
                  Text(
                    area,
                    style: AppTextStyles.medium18.copyWith(color: AppColors.kSecondaryColor, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: AppTextStyles.regular14.copyWith(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.showOnMap,
                    style: AppTextStyles.regular14.copyWith(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.map, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.kSecondaryLightColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: AppColors.kPrimaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.regular14.copyWith(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.bold14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWidget(BuildContext context, String label, IconData icon, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.kSecondaryLightColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: AppColors.kPrimaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.regular14.copyWith(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.bold16),
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context, String title, String time, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.kPrimaryColor : Colors.grey.shade300,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: isCompleted
                  ? [BoxShadow(color: AppColors.kPrimaryColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bold14),
                Text(time, style: AppTextStyles.regular14.copyWith(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatMeters(double meters, AppLocalizations l10n) {
    final km = meters / 1000;
    return km < 1
        ? '${meters.round()} ${l10n.m}'
        : '${km.toStringAsFixed(1)} ${l10n.km}';
  }

  String _getStatusText(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context)!;
    return switch (status) {
      'PENDING'     => l10n.pending,
      'IN_PROGRESS' => l10n.inProgress,
      'DELIVERED'   => l10n.delivered,
      'CANCELLED'   => l10n.cancelled,
      _             => status,
    };
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _completeDelivery(OrderModel order) async {
    final result = await BiometricManager().verifyBiometric(context: context);
    switch (result) {
      case BiometricVerifyResult.passed:
        break;
      case BiometricVerifyResult.canceled:
        return;
      case BiometricVerifyResult.failed:
        if (mounted) showInfoBanner(context, AppLocalizations.of(context)!.verify);
        return;
    }

    dLog('order.courierId : ${order.courierId}');
    if(order.actualPrice == null || order.actualPrice!.isEmpty){
      _actualPriceController.text = order.budget ?? '';
    }
    if (mounted) {
      context.read<OrderCubit>().completeDelivery(
        orderId:    order.id,
        courierId:  order.courierId ?? 1,
        customerId: order.customer?.id ?? 1,
        actualPrice: double.parse(_actualPriceController.text),
      );
    }
  }

  Future<void> _showCancelDialog(BuildContext context, OrderModel order, {required bool isUnavailable}) =>
      showCancelOrderSheet(context: context, isUnavailable: isUnavailable, orderId: order.id);

  Future<void> _showReportHighPriceDialog(BuildContext context, OrderModel order) =>
      showReportHighPriceSheet(context: context, budgetAmount: order.actualPrice ?? order.budget ?? '', orderId: order.id);
}