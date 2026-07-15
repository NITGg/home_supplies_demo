import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tawreedat_courier/core/widgets/banners.dart';
import 'package:tawreedat_courier/core/widgets/circel_back_button.dart';
import 'package:tawreedat_courier/features/orders/presentation/order_details/proposal_status_section.dart';
import 'package:tawreedat_courier/features/orders/presentation/order_details/wallet_limit_dailog.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/calculate_distance.dart';
import '../../../../core/utils/distance_service.dart';
import '../../../../core/utils/location_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/phone_dialer.dart';
import '../../../../core/utils/socket_service.dart';
import '../../../../core/widgets/image_with_fallback.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/manager/profile_cubit.dart';
import '../../../stats/manager/stats_cubit.dart';
import '../../data/models/orders_model.dart';
import '../../manager/orders_cubit.dart';
import '../../manager/orders_states.dart';
import '../active_order/active_order_helpers.dart';
import '../widgets/route_map_widget.dart';
import 'not_approved_banner.dart';
import 'offer_form.dart';

// ── Helper: compute original and after-discount double values ─────────────────

({double original, double afterDiscount}) _computeDiscounted(
    String? rawAmount,
    String? discountStr,
    ) {
  final original = double.tryParse(rawAmount ?? '0') ?? 0;
  final discount = double.tryParse(discountStr ?? '0') ?? 0;
  return (
  original: original,
  afterDiscount: (original - discount).clamp(0, double.infinity),
  );
}

// ── Widget: shows strikethrough original + green after-discount value ─────────

class _DiscountedValue extends StatelessWidget {
  final double original;
  final double afterDiscount;
  final String currency;
  final TextStyle? baseStyle;

  const _DiscountedValue({
    required this.original,
    required this.afterDiscount,
    required this.currency,
    this.baseStyle,
  });

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final hasDiscount = afterDiscount < original;
    final style = baseStyle ?? AppTextStyles.bold25;

    if (!hasDiscount) {
      return Text('${_fmt(original)} $currency', style: style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_fmt(original)} $currency',
          style: style.copyWith(
            decoration: TextDecoration.lineThrough,
            color: Colors.grey.shade400,
            fontSize: (style.fontSize ?? 20) - 4,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_fmt(afterDiscount)} $currency',
              style: style.copyWith(color: Colors.green.shade700),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                '↓ ${_fmt(original - afterDiscount)} $currency',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final TextEditingController _feeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  late OrderModel _currentOrder;
  late double _estimatedFee;
  late double _maxFee;
  late double _minFee;

  // ── Fee bounds state ──────────────────────────────────────────────────────
  bool _checkingWalletLimit = true;
  bool _fetchingFeeBounds = false;
  bool _feeBoundsError = false;
  bool _isPeakTime = false;
  double _peakTimeSurcharge = 0;
  double _appliedBonus = 0;

  DistanceResult? _distanceToPickup;
  bool _fetchingDistance = true;
  bool _offerSubmittedThisSession = false;
  bool _fixedFeeRespondedThisSession = false;

  StreamSubscription? _offerRejectedSubscription;
  StreamSubscription? _orderCancelledSubscription;

  OverlayEntry? _loadingOverlay;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _estimatedFee = 0;
    _maxFee = 0;
    _minFee = 0;

    // Start loading fee bounds immediately for non-fixed-fee pending orders
    _fetchingFeeBounds =
        _currentOrder.status == 'PENDING' && !_currentOrder.isFixedFee;

    _setupSocketListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ProfileCubit>().fetchProfile();
      if (!mounted) return;

      if (context.read<StatsCubit>().badgeProgress == null) {
        await context.read<StatsCubit>().fetchBadgeProgress();
      }

      final futures = <Future>[
        if (mounted) context.read<OrderCubit>().aboveWalletLimit(context),
        if (_currentOrder.status == 'PENDING') _fetchDistanceToPickup(),
        if (_currentOrder.status == 'PENDING' && !_currentOrder.isFixedFee)
          _fetchFeeBounds(),
      ];

      final results = await Future.wait(futures);

      if (!mounted) return;

      if (mounted) setState(() => _checkingWalletLimit = false);

      final isBlocked = results.first as bool;
      dLog('isBlocked: $isBlocked');
      if (isBlocked) showWalletLimitExceededDialog(context);
    });
  }

  // ── Fetch fee bounds from server ──────────────────────────────────────────

  Future<void> _fetchFeeBounds() async {
    if (mounted) setState(() { _fetchingFeeBounds = true; _feeBoundsError = false; });

    try {
      final response = await ApiClient.instance.dio2.get(
        '/orders/${_currentOrder.id}/fee-bounds',
      );

      if (!mounted) return;

      // Support both wrapped { data: {...} } and flat response shapes
      final raw = response.data;
      final data = (raw is Map && raw.containsKey('data')) ? raw['data'] : raw;

      final minCents =
          (data['minCourierFee'] as num?)?.toDouble() ?? 0;
      final suggestedCents =
          (data['suggestedCourierFee'] as num?)?.toDouble() ?? 0;
      final maxCents =
          (data['maxCourierFee'] as num?)?.toDouble() ?? 0;
      final peakSurchargeCents =
          double.tryParse(data['peakTimeSurcharge']?.toString() ?? '0') ?? 0;
      final bonusCents =
          double.tryParse(data['appliedBonus']?.toString() ?? '0') ?? 0;
      final isPeak = data['isPeakTime'] as bool? ?? false;

      dLog(
        '_fetchFeeBounds => '
            'min: ${minCents / 100}, '
            'suggested: ${suggestedCents / 100}, '
            'max: ${maxCents / 100}, '
            'isPeak: $isPeak, '
            'peakSurcharge: ${peakSurchargeCents / 100}, '
            'bonus: ${bonusCents / 100}',
      );

      setState(() {
        _minFee = minCents / 100;
        _estimatedFee = suggestedCents / 100;
        _maxFee = maxCents / 100;
        _isPeakTime = isPeak;
        _peakTimeSurcharge = peakSurchargeCents / 100;
        _appliedBonus = bonusCents / 100;
        _fetchingFeeBounds = false;
        _feeBoundsError = false;
      });
    } catch (e) {
      dLog('Fee bounds fetch error: $e');
      if (mounted) {
        setState(() {
          _fetchingFeeBounds = false;
          _feeBoundsError = true;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  void _setupSocketListeners() {
    _offerRejectedSubscription = SocketService().onOfferRejected.listen((data) {
      if (!mounted) return;
      final rejectedOrderId = data['orderId'] as int?;
      if (rejectedOrderId != null && rejectedOrderId != widget.order.id) return;

      final l10n = AppLocalizations.of(context)!;
      showInfoBanner(context, '${l10n.offerRejected}\n${l10n.canSubmitAgain}');
      context.pop();
    });

    _orderCancelledSubscription = SocketService().onOrderCancelled.listen((
        data,
        ) {
      if (!mounted) return;
      final cancelledOrderId = data['orderId'] as int?;
      if (cancelledOrderId != null && cancelledOrderId != widget.order.id) {
        return;
      }

      final l10n = AppLocalizations.of(context)!;
      showInfoBanner(context, l10n.orderCancelled);
      context.pop();
    });
  }

  Future<void> _fetchDistanceToPickup() async {
    if (mounted) setState(() => _fetchingDistance = true);

    final position = await LocationService.instance.getCurrentLocation(
      context: context,
    );

    if (!mounted) return;

    if (position == null) {
      setState(() => _fetchingDistance = false);
      return;
    }

    try {
      final result = await DistanceService.instance.fetchDistance(
        pickupLat: position.latitude,
        pickupLng: position.longitude,
        deliveryLat: double.parse(_currentOrder.pickupLat ?? '0'),
        deliveryLng: double.parse(_currentOrder.pickupLong ?? '0'),
      );
      if (mounted) {
        setState(() {
          _distanceToPickup = result;
          _fetchingDistance = false;
        });
      }
    } catch (e) {
      debugPrint('Distance fetch error: $e');
      if (mounted) setState(() => _fetchingDistance = false);
    }
  }

  Future<void> _openInMaps(
      String lat,
      String lng,
      String shortDestinationText,
      ) async {
    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    final geoUrl = 'geo:$lat,$lng?q=$lat,$lng($shortDestinationText)';
    final appleMapsUrl =
        'maps://?saddr=Current%20Location&daddr=$lat,$lng&dirflg=d';

    try {
      if (Platform.isAndroid) {
        if (!await launchUrlString(
          geoUrl,
          mode: LaunchMode.externalApplication,
        )) {
          await launchUrlString(
            googleMapsUrl,
            mode: LaunchMode.externalApplication,
          );
        }
      } else if (Platform.isIOS) {
        if (!await launchUrlString(
          appleMapsUrl,
          mode: LaunchMode.externalApplication,
        )) {
          await launchUrlString(
            googleMapsUrl,
            mode: LaunchMode.externalApplication,
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening maps: $e');
      await launchUrlString(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  void _showLoadingOverlay() {
    _loadingOverlay?.remove();
    _loadingOverlay = OverlayEntry(
      builder: (_) => const ColoredBox(
        color: Colors.black26,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.orange,
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_loadingOverlay!);
  }

  void _hideLoadingOverlay() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
  }

  @override
  void dispose() {
    _offerRejectedSubscription?.cancel();
    _orderCancelledSubscription?.cancel();
    _feeController.dispose();
    _hideLoadingOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: CircleBackButton(),
        title: Text(
          l10n.orderDetails,
          style: AppTextStyles.bold18.copyWith(
            color: AppColors.kSecondaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<OrderCubit, OrderState>(
        listener: (context, state) {
          if (state is SubmittingOffer) {
            setState(() => _isSubmitting = true);
            _showLoadingOverlay();
          } else if (state is OfferSubmitted) {
            _hideLoadingOverlay();
            setState(() => _offerSubmittedThisSession = true);
            if (context.mounted) context.pop(true);
            showSuccessBanner(context, l10n.offerSubmittedSuccessfully);
          } else if (state is OfferSubmitError) {
            _hideLoadingOverlay();
            setState(() {
              _isSubmitting = false;
              if (state.order != null) _currentOrder = state.order!;
            });
            showErrorBanner(context, state.message);
          } else if (state is RespondingToFixedFee) {
            _showLoadingOverlay();
          } else if (state is FixedFeeResponseSuccess) {
            _hideLoadingOverlay();
            setState(() => _fixedFeeRespondedThisSession = true);
            final msg = state.action == 'ACCEPT'
                ? l10n.accepted
                : l10n.rejected;
            if (state.action == 'ACCEPT') {
              showSuccessBanner(context, msg);
              if (context.mounted) context.pop('fixed_fee_accepted');
            } else {
              showInfoBanner(context, msg);
              if (context.mounted) context.pop();
            }
          } else if (state is FixedFeeResponseError) {
            _hideLoadingOverlay();
            setState(() {
              if (state.order != null) _currentOrder = state.order!;
            });
            showErrorBanner(context, state.message);
          }
        },
        builder: (context, state) {
          return _buildOrderDetails(context, _currentOrder);
        },
      ),
    );
  }

  Widget _buildOrderDetails(BuildContext context, OrderModel order) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductSection(context, l10n, order),
          const SizedBox(height: 12),
          if (order.customer != null && order.status == 'PENDING')
            _buildCustomerSection(context, l10n, order),
          const SizedBox(height: 12),
          _buildOrderInfoSection(context, l10n, order),
          const SizedBox(height: 12),
          if (order.status == 'PENDING')
            _buildRouteSection(context, l10n, order),
          const SizedBox(height: 12),
          _buildSubmitOfferSection(context, l10n, order),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
        ],
      ),
    );
  }

  // ── Product section ───────────────────────────────────────────────────────────

  Widget _buildProductSection(
      BuildContext context,
      AppLocalizations l10n,
      OrderModel order,
      ) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Catalog items list ─────────────────────────────────────────────
          if (order.isCatalogPurchase) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: order.orderItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ImageWithIconFallback(
                          imageUrl: item.product.images.isNotEmpty
                              ? item.product.images.first
                              : '',
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
                            Text(
                              item.product.nameAr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('${l10n.quantity}: ${item.quantity}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // ── Hero product image (non-catalog) ───────────────────────────────
          if (!order.isCatalogPurchase)
            Center(
              child: Hero(
                tag: 'order-image-${order.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.kPrimaryColor.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ImageWithIconFallback(
                      imageUrl: order.productImage,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.scaleDown,
                      iconSize: 70,
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // ── Order number chip ──────────────────────────────────────────────
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                order.orderNumber,
                style: AppTextStyles.bold14.copyWith(
                  color: AppColors.kPrimaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            order.productDescription ?? '',
            style: AppTextStyles.bold18.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),

          // ── Budget / price badge (with discount) ──────────────────────────
          _buildBudgetOrShippingBadge(context, l10n, order),
        ],
      ),
    );
  }

  Widget _buildBudgetOrShippingBadge(
      BuildContext context,
      AppLocalizations l10n,
      OrderModel order,
      ) {
    final String? displayPrice = order.isCatalogPurchase
        ? (order.costPrice)
        : (order.budget != null && order.budget != '0'
        ? (order.actualPrice != null && order.actualPrice != '0.00'
        ? order.actualPrice
        : order.budget)
        : null);

    final bool hasPriceToShow =
        displayPrice != null &&
            displayPrice != '0' &&
            displayPrice != '0.00' &&
            displayPrice != '0.01';

    final priceResult = (
    original: double.tryParse(displayPrice ?? '0') ?? 0,
    afterDiscount: double.tryParse(displayPrice ?? '0') ?? 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.kSecondaryColor.withOpacity(0.1),
            AppColors.kSecondaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kSecondaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasPriceToShow
                  ? Icons.account_balance_wallet
                  : Icons.inventory_2_rounded,
              color: AppColors.kSecondaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: hasPriceToShow
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.isCatalogPurchase
                      ? l10n.price
                      : l10n.customerBudget,
                  style: AppTextStyles.regular14.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                _DiscountedValue(
                  original: priceResult.original,
                  afterDiscount: priceResult.afterDiscount,
                  currency: l10n.egp,
                  baseStyle: AppTextStyles.bold25.copyWith(fontSize: 20),
                ),
              ],
            )
                : Text(
              l10n.shipping,
              style: AppTextStyles.regular14.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Customer section ──────────────────────────────────────────────────────────

  Widget _buildCustomerSection(
      BuildContext context,
      AppLocalizations l10n,
      OrderModel order,
      ) {
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
                  child: order.customer?.personalPhoto != null
                      ? ClipOval(
                    child: ImageWithIconFallback(
                      imageUrl: order.customer?.personalPhoto,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  )
                      : const Icon(
                    Icons.person,
                    color: AppColors.kPrimaryColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customer!.fullName,
                        style: AppTextStyles.bold16,
                      ),
                      if (order.customer?.phone != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          order.customer!.phone!,
                          textDirection: ui.TextDirection.ltr,
                          style: AppTextStyles.regular14.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (order.customer?.phone != null)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.kPrimaryColor,
                          AppColors.kPrimaryColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.phone, color: Colors.white),
                      onPressed: () =>
                          openPhoneApp(order.customer?.phone ?? ''),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Order info section ────────────────────────────────────────────────────────

  Widget _buildOrderInfoSection(
      BuildContext context,
      AppLocalizations l10n,
      OrderModel order,
      ) {
    final isPending = order.status == 'PENDING';

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.orderInformation, style: AppTextStyles.bold16),
          const SizedBox(height: 16),
          _buildInfoRow(
            context,
            l10n.paymentMethod,
            order.paymentMethod,
            Icons.payment,
          ),
          if (!isPending) ...[
            _buildInfoRow(
              context,
              l10n.status,
              _getStatusText(context, order.status),
              Icons.info_outline,
            ),
            _buildInfoRow(
              context,
              l10n.created,
              DateFormat('MMM dd, yyyy - hh:mm a').format(order.createdAt),
              Icons.calendar_today,
            ),
          ],
        ],
      ),
    );
  }

  // ── Route section ─────────────────────────────────────────────────────────────

  Widget _buildRouteSection(
      BuildContext context,
      AppLocalizations l10n,
      OrderModel order,
      ) {
    final isArabic = AppLocalizations.of(context)!.localeName == 'ar';

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentOrder.status == 'PENDING')
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 5,
              children: [
                if (_fetchingDistance)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  )
                else if (_distanceToPickup != null)
                  _infoChipRow(
                    label: l10n.toPickup,
                    icon: Icons.near_me_rounded,
                    value: _formatMeters(
                      _distanceToPickup!.distanceMeters,
                      l10n,
                    ),
                    duration: _formatDuration(
                      _distanceToPickup!.durationSeconds,
                      l10n,
                    ),
                    color: Colors.lightBlue,
                  ),
                if (order.distanceM != '0')
                  _infoChipRow(
                    label:
                    '${l10n.from} ${l10n.pickupLocation} ${l10n.to} ${l10n.deliveryLocation}',
                    icon: Icons.route_rounded,
                    value: distanceLabelFromString(
                      context,
                      order.distanceM ?? '0',
                    ),
                    color: AppColors.kPrimaryColor,
                  ),
              ],
            ),
          const SizedBox(height: 12),
          if (order.status == 'PENDING') ...[
            RouteMapWidget(
              pickupLat: double.parse(order.pickupLat ?? '0'),
              pickupLng: double.parse(order.pickupLong ?? '0'),
              deliveryLat: double.parse(order.deliveryLat ?? '0'),
              deliveryLng: double.parse(order.deliveryLong ?? '0'),
            ),
            const SizedBox(height: 12),
          ],
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
          Padding(
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
                      gradient: LinearGradient(
                        colors: [
                          AppColors.kPrimaryColor.withOpacity(0.3),
                          Colors.green.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_downward,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
          _buildLocationDetail(
            context: context,
            icon: Icons.location_on,
            title: l10n.deliveryLocation,
            area: isArabic
                ? order.deliveryArea!.nameAr
                : order.deliveryArea!.name,
            address: order.deliveryAddressDescription,
            color: Colors.green,
            lat: order.deliveryLat,
            lng: order.deliveryLong,
          ),
        ],
      ),
    );
  }

  // ── Submit offer section ──────────────────────────────────────────────────────

  Widget _buildSubmitOfferSection(
      BuildContext context,
      AppLocalizations l10n,
      OrderModel order,
      ) {
    final profile = context.read<ProfileCubit>().currentProfile;
    final isApproved = profile?.courier.isApproved ?? false;

    if (!isApproved) return const NotApprovedBanner();

    if (_checkingWalletLimit) return _buildFeeBoundsLoading(l10n);

    // ── Fixed-fee orders ────────────────────────────────────────────────────
    if (order.isFixedFee && order.status == 'PENDING') {
      if (_fixedFeeRespondedThisSession) return const SizedBox.shrink();
      return _buildFixedFeeResponseSection(context, l10n, order);
    }

    // ── Regular (negotiable) offer flow ─────────────────────────────────────
    if (_offerSubmittedThisSession) return const SizedBox.shrink();

    // Show loading while fetching fee bounds from server
    if (_fetchingFeeBounds) {
      return _buildFeeBoundsLoading(l10n);
    }

    // Show retry if fetch failed
    if (_feeBoundsError) {
      return _buildFeeBoundsError(l10n);
    }

    if (order.proposalHistory != null && order.proposalHistory!.isNotEmpty) {
      return Column(
        children: [
          ProposalStatusSection(order: order),
          if (order.canSubmitProposal) _buildOfferForm(isResubmit: true),
        ],
      );
    }

    if (order.canSubmitProposal) return _buildOfferForm(isResubmit: false);

    return const SizedBox.shrink();
  }

  // ── Fee bounds loading placeholder ───────────────────────────────────────────

  Widget _buildFeeBoundsLoading(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'جاري حساب تفاصيل العرض...',
            style: AppTextStyles.regular14.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Fee bounds error state ────────────────────────────────────────────────────

  Widget _buildFeeBoundsError(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.grey.shade400, size: 36),
          const SizedBox(height: 10),
          Text(
            'تعذر تحميل بيانات العرض',
            style: AppTextStyles.bold14.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _fetchFeeBounds,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة المحاولة'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.kPrimaryColor,
              side: BorderSide(color: AppColors.kPrimaryColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Fixed-fee response section ────────────────────────────────────────────────

  Widget _buildFixedFeeResponseSection(
      BuildContext context,
      AppLocalizations l10n,
      OrderModel order,
      ) {
    final rawFeeLabel =
        order.courierFee ?? order.totalFee ?? order.payableAmount;
    final discountHints = buildDiscountHints(order, l10n);

    final applyFeeDiscount =
        order.hasDeliveryFeeDiscount || order.hasOrderTotalDiscount;
    final feeResult = applyFeeDiscount
        ? _computeDiscounted(rawFeeLabel, order.discountAmount)
        : (
    original: double.tryParse(rawFeeLabel ?? '0') ?? 0,
    afterDiscount: double.tryParse(rawFeeLabel ?? '0') ?? 0,
    );

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.question_mark,
                  color: AppColors.kPrimaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.totalFee, style: AppTextStyles.bold16),
                    if (rawFeeLabel != null) ...[
                      const SizedBox(height: 4),
                      _DiscountedValue(
                        original: feeResult.original,
                        afterDiscount: feeResult.afterDiscount,
                        currency: l10n.egp,
                        baseStyle: AppTextStyles.bold25.copyWith(fontSize: 18),
                      ),
                      if (applyFeeDiscount) ...[
                        const SizedBox(height: 8),
                        ...discountHints,
                      ],
                      Text(
                        '\n${l10n.serviceFee}\n ${order.platformFee} ${l10n.egp}',
                        style: AppTextStyles.bold16,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _respondToFixedFee('REJECT'),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(
                    l10n.reject,
                    style: AppTextStyles.bold14.copyWith(fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _respondToFixedFee('ACCEPT'),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    l10n.accept,
                    style: AppTextStyles.bold14.copyWith(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Whether the order's price (budget for custom orders, products total for
  /// catalog orders) falls outside the courier's currently allowed order
  /// price range. Acts as a tap-time safety net — under normal operation,
  /// out-of-range orders are filtered out of the available-orders list
  /// before they're ever shown (see OrderCubit._filterOrdersWithinPriceRange).
  bool get _isPriceOutOfAllowedRange {
    final priceRange = context.read<OrderCubit>().priceRange;
    if (priceRange == null) {
      dLog('Price range check skipped: no priceRange available');
      return false;
    }

    final relevantPrice = _currentOrder.isCatalogPurchase
        ? _currentOrder.productsTotal
        : _currentOrder.budget;
    final price = double.tryParse(relevantPrice ?? '');

    final outOfRange = price != null &&
        (price < priceRange.allowedMinOrderPrice ||
            price > priceRange.allowedMaxOrderPrice);

    dLog(
      'Price range check: orderId=${_currentOrder.id}, '
      'isCatalogPurchase=${_currentOrder.isCatalogPurchase}, '
      'price=$price, '
      'allowedMin=${priceRange.allowedMinOrderPrice}, '
      'allowedMax=${priceRange.allowedMaxOrderPrice}, '
      'outOfRange=$outOfRange',
    );

    return outOfRange;
  }

  /// Builds the detailed out-of-range hint (showing the order's price and the
  /// courier's currently allowed range), or null if the order is in range /
  /// no price range data is available yet.
  String? _priceOutOfRangeMessage(AppLocalizations l10n) {
    final priceRange = context.read<OrderCubit>().priceRange;
    if (priceRange == null || !_isPriceOutOfAllowedRange) return null;

    final relevantPrice = _currentOrder.isCatalogPurchase
        ? _currentOrder.productsTotal
        : _currentOrder.budget;
    final price = double.tryParse(relevantPrice ?? '') ?? 0;

    return l10n.orderPriceOutOfAllowedRangeDetailed(
      price.toStringAsFixed(0),
      priceRange.allowedMinOrderPrice.toStringAsFixed(0),
      priceRange.allowedMaxOrderPrice.toStringAsFixed(0),
    );
  }

  /// Shows the out-of-range error banner if applicable. Returns true when
  /// the action should be blocked.
  bool _blockIfPriceOutOfAllowedRange() {
    final l10n = AppLocalizations.of(context)!;
    final message = _priceOutOfRangeMessage(l10n);
    if (message == null) return false;

    showErrorBanner(context, message);
    return true;
  }

  void _respondToFixedFee(String action) {
    if (action == 'ACCEPT' && _blockIfPriceOutOfAllowedRange()) return;

    context.read<OrderCubit>().respondToFixedFee(
      orderId: widget.order.id,
      action: action,
    );
  }

  Widget _buildOfferForm({required bool isResubmit}) {
    final hasDiscount = _currentOrder.couponType == 'DELIVERY_FEE';
    final l10n = AppLocalizations.of(context)!;
    final discountHints = buildDiscountHints(_currentOrder, l10n);
    final hasNonLockingHints = discountHints.isNotEmpty && !hasDiscount;

    dLog('─── hasDiscount: $hasDiscount , ${_currentOrder.discountAmount}');
    dLog('─── isPeakTime: $_isPeakTime, peakSurcharge: $_peakTimeSurcharge, bonus: $_appliedBonus');
    dLog('min: $_minFee, est: $_estimatedFee, max: $_maxFee');

    final form = OfferForm(
      isLocating: _fetchingDistance,
      isResubmit: isResubmit,
      isSubmitting: _isSubmitting,
      formKey: _formKey,
      feeController: _feeController,
      minFee: _minFee,
      maxFee: hasDiscount ? _estimatedFee : _maxFee,
      estimatedFee: _estimatedFee,
      hasDiscount: hasDiscount,
      customerDiscountAmount: hasDiscount
          ? (double.tryParse(_currentOrder.discountAmount ?? '0') ?? 0)
          : null,
      onSubmit: _submitOffer,
      distanceM: _currentOrder.distanceM,
      isPeakTime: _isPeakTime,
      peakTimeSurcharge: _peakTimeSurcharge,
      appliedBonus: _appliedBonus,
    );

    if (!hasNonLockingHints) return form;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: discountHints,
          ),
        ),
        form,
      ],
    );
  }

  // ── Shared small widgets ──────────────────────────────────────────────────────

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.regular14.copyWith(
              fontSize: 10,
              color: color.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: AppTextStyles.bold14.copyWith(
                  fontSize: 13,
                  color: color,
                ),
              ),
              if (duration != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 1,
                  height: 12,
                  color: color.withOpacity(0.3),
                ),
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: color.withOpacity(0.8),
                ),
                const SizedBox(width: 3),
                Text(
                  duration,
                  style: AppTextStyles.bold14.copyWith(
                    fontSize: 13,
                    color: color.withOpacity(0.85),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatMeters(double meters, AppLocalizations l10n) {
    final km = meters / 1000;
    return km < 1
        ? '${meters.round()} ${l10n.m}'
        : '${km.toStringAsFixed(1)} ${l10n.km}';
  }

  String _formatDuration(int seconds, AppLocalizations l10n) {
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins ${l10n.min}';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h${l10n.hour}' : '$h${l10n.hour} $m ${l10n.min}';
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
                  Text(
                    title,
                    style: AppTextStyles.bold14.copyWith(color: color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    area,
                    style: AppTextStyles.medium18.copyWith(
                      color: AppColors.kSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: AppTextStyles.regular14.copyWith(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context)!.showOnMap,
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

  Widget _buildInfoRow(
      BuildContext context,
      String label,
      String value,
      IconData icon,
      ) {
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
                Text(
                  label,
                  style: AppTextStyles.regular14.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.bold14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case 'PENDING':
        return l10n.pending;
      case 'IN_PROGRESS':
        return l10n.inProgress;
      case 'DELIVERED':
        return l10n.delivered;
      case 'CANCELLED':
        return l10n.cancelled;
      default:
        return status;
    }
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_blockIfPriceOutOfAllowedRange()) return;

    setState(() => _isSubmitting = true);

    final vehicleId = context.read<ProfileCubit>().currentVehicleId;
    if (vehicleId == null) {
      setState(() => _isSubmitting = false);
      showErrorBanner(
        context,
        AppLocalizations.of(context)!.vehicleNotAssigned,
      );
      return;
    }

    if (_distanceToPickup == null) {
      setState(() => _isSubmitting = false);
      showErrorBanner(
        context,
        AppLocalizations.of(context)!.locationUnavailable,
      );
      return;
    }

    final fee = (double.parse(_feeController.text) * 100).round();
    if (mounted) {
      context.read<OrderCubit>().submitOffer(
        orderId: widget.order.id,
        totalFee: fee,
        distanceToPickup: _distanceToPickup!.distanceMeters,
        timeToPickup: _distanceToPickup!.durationSeconds,
        vehicleId: vehicleId,
      );
    }
  }
}