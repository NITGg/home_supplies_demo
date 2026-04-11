import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';
import 'package:tawreedat_go/core/style/text_styles.dart';
import 'package:tawreedat_go/core/utils/app_dynamic_settings.dart';
import 'package:tawreedat_go/core/widgets/banners.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/sheets/create_order_sheet/select_address.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';

import '../../../../../../core/utils/area_boundry_validator.dart';
import '../../../../../../core/utils/distance_service.dart';
import '../../../../../../core/widgets/custom_button.dart';
import '../../../../../../core/widgets/text_form.dart';
import '../../../../../addresses/data/models/address_model.dart';
import '../../../../../addresses/data/models/governorate_model.dart';
import '../../../../../addresses/manager/address_cubit.dart';
import '../../../../../addresses/manager/address_states.dart';
import '../../../../../coupons/manager/coupons_cubit.dart';
import '../../../../../wallet/manager/wallet_cubit.dart';
import '../../../../../wallet/manager/wallet_state.dart';
import '../../../../data/models/order_model.dart';
import '../../../../manager/order_cubit.dart';
import '../../../../manager/order_states.dart';
import 'coupon_section.dart';
import 'product_image_picker.dart';
import 'toggle_tab.dart';

class CreateOrderBottomSheet extends StatefulWidget {
  final GovernoratesResponse governorates;
  final double? walletBalance;
  final String? initialCouponCode; // ← NEW

  const CreateOrderBottomSheet({
    super.key,
    required this.governorates,
    this.walletBalance,
    this.initialCouponCode,
  });

  @override
  State<CreateOrderBottomSheet> createState() => _CreateOrderBottomSheetState();
}

class _CreateOrderBottomSheetState extends State<CreateOrderBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _productDescriptionFocus = FocusNode();
  final FocusNode _budgetFocus = FocusNode();
  final FocusNode _couponFocus = FocusNode();

  final _productDescriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _couponController = TextEditingController();

  Address? _pickupAddress;
  Address? _deliveryAddress;
  File? _productImage;

  bool _isShopping = true;
  String _paymentMethod = 'CASH';
  bool _pickupNearMe = false;

  // ── Distance state (replaces the old synchronous calculateDistance call) ──
  DistanceResult? _distanceResult; // null = not yet fetched / addresses missing
  bool _fetchingDistance = false;

  CouponValid? _appliedCoupon;
  bool _couponValidating = false;

  late double _walletBalance;
  late final AddressCubit _initCubit;

  // ── Life-cycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    context.read<WalletCubit>().fetchWalletData();
    _budgetController.addListener(() => setState(() {}));
    _walletBalance = widget.walletBalance ?? 0.0;
    _initCubit = AddressCubit();
    _preloadDefaultDelivery();

    // Always resolve through the cubit — handles both dialog and direct-open flows.
    // If the dialog already checked, the result is cached (no extra API call).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final code = widget.initialCouponCode?.isNotEmpty == true
          ? widget.initialCouponCode          // explicit override (e.g. deep link)
          : await context                     // cubit handles caching + eligibility
          .read<CouponCubit>()
          .getOrFetchFirstOrderCoupon();

      if (!mounted || code == null || code.isEmpty) return;
      _couponController.text = code;
      _validateCoupon();
    });
  }

  Future<void> _preloadDefaultDelivery() async {
    _initCubit.stream.listen((state) {
      if (!mounted) return;
      if (state is AddressesLoaded && state.addresses.isNotEmpty) {
        final defaultAddr = state.addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => state.addresses.first,
        );
        if (_deliveryAddress == null) {
          setState(() => _deliveryAddress = defaultAddr);
          _fetchDistanceIfReady(); // try fetching once default is loaded
        }
      }
    });
    await _initCubit.loadAddresses();
  }

  @override
  void dispose() {
    _initCubit.close();
    _productDescriptionController.dispose();
    _budgetController.dispose();
    _couponController.dispose();
    _productDescriptionFocus.dispose();
    _budgetFocus.dispose();
    _couponFocus.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Address? get _effectivePickup =>
      _pickupNearMe ? _deliveryAddress : _pickupAddress;

  Area? _areaFor(Address address) =>
      widget.governorates.findAreaById(address.areaId);

  bool _isAddressInArea(Address address) {
    final area = _areaFor(address);
    if (area == null) return true;
    return AreaBoundaryValidator.isPointInArea(
      lat: double.parse(address.addressLat),
      lng: double.parse(address.addressLong),
      boundaries: area.boundaries,
    );
  }

  // ── Distance fetching ──────────────────────────────────────────────────────

  /// Calls POST /distances whenever both addresses are available.
  /// Resets [_distanceResult] and shows a spinner while waiting.
  Future<void> _fetchDistanceIfReady() async {
    final pickup = _effectivePickup;
    final delivery = _deliveryAddress;

    if (pickup == null || delivery == null) {
      if (mounted) setState(() => _distanceResult = null);
      return;
    }

    if (mounted) {
      setState(() {
        _fetchingDistance = true;
        _distanceResult = null;
      });
    }

    try {
      final result = await DistanceService.instance.fetchDistance(
        pickupLat: double.parse(pickup.addressLat),
        pickupLng: double.parse(pickup.addressLong),
        deliveryLat: double.parse(delivery.addressLat),
        deliveryLng: double.parse(delivery.addressLong),
      );

      log(
        '📏 [Distance] ${result.distanceMeters} m  '
        '⏱ ${result.durationSeconds} s  '
        '(${result.provider})',
      );

      if (mounted) setState(() => _distanceResult = result);
    } catch (e) {
      log('❌ [Distance] fetch failed: $e');
      if (mounted) setState(() => _distanceResult = null);
    } finally {
      if (mounted) setState(() => _fetchingDistance = false);
    }
  }

  // ── Fee calculation ────────────────────────────────────────────────────────

  /// Returns the shipping fee in EGP using the already-fetched distance,
  /// or null when the distance is not yet available.
  double? _calculateShippingFee() {
    if (_distanceResult == null) return null;

    final rawFeePerKm =
        double.tryParse(AppSettings.delivery_price_for_each_1km ?? '0') ?? 1000;
    final rawMinFee =
        double.tryParse(AppSettings.min_delivery_fee ?? '0') ?? 3000;

    final double feePerKm = rawFeePerKm / 100;
    final double minFee = rawMinFee / 100;

    final distanceMeters = _distanceResult!.distanceMeters;
    final calculatedFee = distanceMeters * feePerKm / 1000;
    final fee = calculatedFee < minFee ? minFee : calculatedFee;
    final finalFee = fee.ceilToDouble();

    log('🚚 [Shipping] dist=${distanceMeters}m  fee=$finalFee EGP');
    return finalFee;
  }

  double _requiredWalletAmount() {
    final rawFee = _calculateShippingFee() ?? 0.0;

    // Apply coupon discount to the fee if applicable
    double fee = rawFee;
    if (_appliedCoupon != null && _appliedCoupon!.isDeliveryFeeDiscount) {
      if (_appliedCoupon!.isPercentDiscount && _appliedCoupon!.discountValue != null) {
        fee = (rawFee - (rawFee * _appliedCoupon!.discountValue! / 100)).clamp(0, double.infinity);
      } else if (_appliedCoupon!.isFixedDiscount && _appliedCoupon!.discountValue != null) {
        fee = (rawFee - _appliedCoupon!.discountValue!).clamp(0, double.infinity);
      }
    }

    if (_isShopping) {
      final budget = double.tryParse(_budgetController.text.trim()) ?? 0.0;
      return fee + budget;
    }
    return fee;
  }

  // ── Coupon ─────────────────────────────────────────────────────────────────

  Future<void> _validateCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _couponValidating = true;
      _appliedCoupon = null;
    });

    context.read<OrderCubit>().validateCoupon(code);
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponController.clear();
    });
  }

  // ── Address sheet ──────────────────────────────────────────────────────────

  Future<void> _selectPickupAddress() async {
    final result = await _openAddressSheet(
      title: AppLocalizations.of(context)!.pickupLocation,
      isPickup: true,
    );
    if (result != null && mounted) {
      setState(() => _pickupAddress = result);
      _fetchDistanceIfReady();
    }
  }

  Future<void> _selectDeliveryAddress() async {
    final result = await _openAddressSheet(
      title: AppLocalizations.of(context)!.deliveryLocation,
      isPickup: false,
    );
    if (result != null && mounted) {
      setState(() => _deliveryAddress = result);
      _fetchDistanceIfReady();
    }
  }

  Future<Address?> _openAddressSheet({
    required String title,
    required bool isPickup,
  }) {
    return showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => AddressCubit(),
        child: AddressSelectionSheet(title: title, isPickup: isPickup),
      ),
    );
  }

  // ── Route section ──────────────────────────────────────────────────────────

  Widget _buildRouteSection(AppLocalizations l10n) {
    final fee = _calculateShippingFee();
    final effectivePickup = _effectivePickup;

    final pickupOutOfBounds =
        effectivePickup != null && !_isAddressInArea(effectivePickup);
    final deliveryOutOfBounds =
        _deliveryAddress != null && !_isAddressInArea(_deliveryAddress!);

    // Distance label — show spinner while fetching, value when ready
    Widget? distanceBadgeChild;
    if (_fetchingDistance) {
      distanceBadgeChild = const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    } else if (_distanceResult != null) {
      final meters = _distanceResult!.distanceMeters;
      final label = meters >= 1000
          ? '${(meters / 1000).toStringAsFixed(1)} ${l10n.km}'
          : '${meters.toStringAsFixed(0)} ${l10n.m}';
      distanceBadgeChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left: icon column with vertical dashed connector ──
            SizedBox(
              width: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (!_pickupNearMe)
                      _buildPinIcon(
                        icon: Icons.store_outlined,
                        color: const Color(0xFF0F6E56),
                        bgColor: const Color(0xFFE1F5EE),
                        warning: pickupOutOfBounds,
                      ),
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: 2,
                          child: CustomPaint(
                            painter: _VerticalDashedLinePainter(
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildPinIcon(
                      icon: Icons.location_on,
                      color: const Color(0xFF185FA5),
                      bgColor: const Color(0xFFE6F1FB),
                      warning: deliveryOutOfBounds,
                    ),
                  ],
                ),
              ),
            ),

            // ── Vertical divider ──
            VerticalDivider(width: 1, color: Colors.grey.shade200),

            // ── Right: address rows ──
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pickup row — hidden when Near Me is active
                  if (!_pickupNearMe)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _selectPickupAddress,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          l10n.pickupLocation,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F6E56),
                                          ),
                                        ),
                                        if (pickupOutOfBounds) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: 13,
                                            color: Colors.orange.shade700,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      effectivePickup?.displayAddress ??
                                          l10n.pickupLocation,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: effectivePickup == null
                                            ? Colors.grey
                                            : Colors.black87,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 13,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Distance badge divider ──
                  if (!_pickupNearMe)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Divider(height: 1, color: Colors.grey.shade200),
                        if (distanceBadgeChild != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.kSecondaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: distanceBadgeChild,
                          ),
                      ],
                    ),

                  // Delivery row
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _selectDeliveryAddress,
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        l10n.deliveryLocation,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF185FA5),
                                        ),
                                      ),
                                      if (deliveryOutOfBounds) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 13,
                                          color: Colors.orange.shade700,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _deliveryAddress?.displayAddress ??
                                        l10n.deliveryLocation,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _deliveryAddress == null
                                          ? Colors.grey
                                          : Colors.black87,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (deliveryOutOfBounds) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      l10n.addressMayBeOutsideArea,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 13,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Payment method toggle ──────────────────────────────────────────────────

  Widget _buildPaymentToggle() {
    final l10n = AppLocalizations.of(context)!;
    final isCash = _paymentMethod == 'CASH';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Stack(
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: isCash
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _paymentMethod = 'CASH'),
                        child: _buildPaymentOption(
                          icon: Icons.payments_outlined,
                          label: _calculateShippingFee() != null
                              ? l10n.codN
                              : l10n.cod,
                          selected: isCash,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _paymentMethod = 'WALLET'),
                        child: _buildPaymentOption(
                          icon: Icons.account_balance_wallet_outlined,
                          label: l10n.wallet,
                          selected: !isCash,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String label,
    required bool selected,
  }) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              key: ValueKey('$icon-$selected'),
              size: 20,
              color: selected
                  ? AppColors.kSecondaryColor
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            textAlign: TextAlign.center,
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: selected
                ? AppTextStyles.bold14.copyWith(fontSize: 9)
                : AppTextStyles.regular14.copyWith(
                    color: Colors.grey,
                    fontSize: 9,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeAndPaymentRow(
    AppLocalizations l10n,
    double fee,
    bool isOverBudget,
  ) {
    // ── Compute discounted fee if a delivery-fee coupon is applied ────────────
    double? discountedFee;
    if (_appliedCoupon != null && _appliedCoupon!.isDeliveryFeeDiscount) {
      if (_appliedCoupon!.isPercentDiscount &&
          _appliedCoupon!.discountValue != null) {
        discountedFee = (fee - (fee * _appliedCoupon!.discountValue! / 100))
            .clamp(0, double.infinity);
      } else if (_appliedCoupon!.isFixedDiscount &&
          _appliedCoupon!.discountValue != null) {
        discountedFee = (fee - _appliedCoupon!.discountValue!).clamp(
          0,
          double.infinity,
        );
      }
    }

    final bool hasFeeDiscount = discountedFee != null;

    final feeChip = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: hasFeeDiscount
            ? Colors.green.shade50
            : AppColors.kSecondaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasFeeDiscount
              ? Colors.green.shade300
              : AppColors.kSecondaryColor.withOpacity(0.25),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l10n.estimatedShippingFee,
            style: TextStyle(
              fontSize: 10,
              color: hasFeeDiscount
                  ? Colors.green.shade700
                  : AppColors.kSecondaryColor.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          if (hasFeeDiscount)
            // ── Show original crossed out + new fee ──────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Original fee — struck through
                Text(
                  '${fee.toInt()} ${l10n.egp}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade400,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.red.shade400,
                  ),
                ),
                const SizedBox(width: 6),
                // Discounted fee
                Text(
                  '${discountedFee!.toInt()} ${l10n.egp}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            )
          else
            Text(
              textAlign: TextAlign.center,
              '${fee.toInt()} ${l10n.egp}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.kSecondaryColor,
              ),
            ),
        ],
      ),
    );

    if (!_isShopping || isOverBudget) return feeChip;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        feeChip,
        const SizedBox(width: 10),
        Expanded(child: _buildPaymentToggle()),
      ],
    );
  }

  // ── Insufficient balance dialog ────────────────────────────────────────────

  void _showInsufficientBalanceDialog({
    required double required,
    required double balance,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final shortfall = (required - balance).ceilToDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return _InsufficientBalanceSheet(
          currentBalance: balance,
          requiredAmount: required,
          shortfall: shortfall,
          isShopping: _isShopping,
          l10n: l10n,
          onTopUp: () async {
            Navigator.pop(sheetCtx);
            await context.push('/wallet/topup');
          },
        );
      },
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  void _submit() {
    final l10n = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) return;

    if (!_isShopping && _productImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.tapToSelectImage)));
      return;
    }

    if (!_pickupNearMe && _pickupAddress == null) {
      Fluttertoast.showToast(
        msg: l10n.pleaseSelectLocation,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }

    if (_deliveryAddress == null) {
      Fluttertoast.showToast(
        msg: l10n.pleaseSelectLocation,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    if (_distanceResult == null) {
      Fluttertoast.showToast(
        msg: l10n.pleaseSelectLocation,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    final effectivePickup = _effectivePickup!;

    if (!_isAddressInArea(effectivePickup)) {
      Fluttertoast.showToast(
        msg: l10n.pickupAddressOutOfArea,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (!_isAddressInArea(_deliveryAddress!)) {
      Fluttertoast.showToast(
        msg: l10n.deliveryAddressOutOfArea,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (!_pickupNearMe) {
      final distanceMeters = _distanceResult!.distanceMeters;
      final minDistance =
          double.tryParse(AppSettings.min_delivery_distance ?? '0') ?? 0;
      if (distanceMeters < minDistance) {
        Fluttertoast.showToast(
          msg: l10n.distanceTooClose,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }
    }

    // ── Fix: compute overbudget here instead of referencing build()'s local var ──
    final budget = double.tryParse(_budgetController.text.trim()) ?? 0;
    final limit =
        (double.tryParse(
              AppSettings.customer_budget_cash_on_delivery_limit ?? '0',
            ) ??
            0) /
        100;
    final isOverBudget = _isShopping && budget > limit;

    final bool usesWallet =
        _paymentMethod == 'WALLET' || !_isShopping || isOverBudget;
    if (usesWallet) {
      final required = _requiredWalletAmount();
      if (_walletBalance < required) {
        _showInsufficientBalanceDialog(
          required: required,
          balance: _walletBalance,
        );
        return;
      }
    }

    context.read<OrderCubit>().createOrder(
      Order(
        productDescription: _productDescriptionController.text.trim(),
        productImageFile: _productImage,
        budget: _isShopping
            ? (double.parse(_budgetController.text.trim()) * 100)
                  .round()
                  .toString()
            : '1',
        pickupAreaId: effectivePickup.areaId,
        pickupAddressDescription: effectivePickup.detailedAddress,
        pickupLat: effectivePickup.addressLat,
        pickupLong: effectivePickup.addressLong,
        deliveryAreaId: _deliveryAddress!.areaId,
        deliveryAddressDescription: _deliveryAddress!.detailedAddress,
        deliveryLat: _deliveryAddress!.addressLat,
        deliveryLong: _deliveryAddress!.addressLong,
      ),
      estimatedDeliveryFee: (_calculateShippingFee() ?? 0 * 100).toString(),
      _isShopping ? _paymentMethod : 'WALLET',
      couponCode: _appliedCoupon?.code,
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildToggle() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        spacing: 5,
        mainAxisSize: MainAxisSize.min,
        children: [
          ToggleTab(
            label: l10n.shopping,
            selected: _isShopping,
            onTap: () => setState(() => _isShopping = true),
          ),
          ToggleTab(
            label: l10n.shipping,
            selected: !_isShopping,
            onTap: () => setState(() => _isShopping = false),
          ),
        ],
      ),
    );
  }

  Widget _buildNearMeCheckbox(AppLocalizations l10n) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _pickupNearMe = !_pickupNearMe;
          if (_pickupNearMe) _pickupAddress = null;
        });
        // Near-Me re-routes pickup through delivery address — re-fetch
        _fetchDistanceIfReady();
      },
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _pickupNearMe,
              activeColor: AppColors.kSecondaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (val) {
                setState(() {
                  _pickupNearMe = val ?? false;
                  if (_pickupNearMe) _pickupAddress = null;
                });
                _fetchDistanceIfReady();
              },
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.my_location_rounded,
            size: 18,
            color: _pickupNearMe
                ? AppColors.kSecondaryColor
                : Colors.grey.shade500,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.nearMe,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _pickupNearMe
                  ? AppColors.kSecondaryColor
                  : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<WalletCubit, WalletState>(
      listenWhen: (_, current) => current is WalletLoaded,
      listener: (context, state) {
        if (state is WalletLoaded) {
          setState(() => _walletBalance = state.walletData.wallet.balance);
        }
      },
      child: BlocListener<OrderCubit, OrderState>(
        listener: (context, state) {
          if (state is CouponValidating) {
            if (!_couponValidating) setState(() => _couponValidating = true);
          } else if (state is CouponRedeemed) {
            setState(() {
              _couponValidating = false;
              if (state.coupon != null) _appliedCoupon = state.coupon;
            });
            Fluttertoast.showToast(
              msg: l10n.couponRedeemed,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.green.shade700,
            );
          } else if (state is CouponInvalid) {
            setState(() => _couponValidating = false);
            Fluttertoast.showToast(
              msg: state.message,
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          } else if (state is CouponRedeemError) {
            setState(() => _couponValidating = false);
            Fluttertoast.showToast(
              msg: state.message,
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.orange,
              textColor: Colors.white,
            );
          } else if (state is OrderSuccess) {
            Navigator.pop(context, state.order);
            showSuccessBanner(
              context,
              '${l10n.created}: ${state.order.orderNumber}',
            );
          } else if (state is OrderError) {
            Fluttertoast.showToast(
              msg: state.message,
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
        },
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            final shippingFee = _calculateShippingFee();
            final budget = double.tryParse(_budgetController.text.trim()) ?? 0;

            final limit =
                (double.tryParse(
                      AppSettings.customer_budget_cash_on_delivery_limit ?? '0',
                    ) ??
                    0) /
                100;

            final isOverBudget = budget > limit;
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.newOrder,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildToggle(),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _isShopping
                                ? (isOverBudget
                                      ? '${l10n.walletBalanceHintOverBudget} $limit ${l10n.walletBalanceHintOverBudget2}'
                                      : l10n.walletBalanceHintShopping)
                                : l10n.walletBalanceHintShipping,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          AppTextFormField(
                            focusNode: _productDescriptionFocus,
                            textInputAction: _isShopping
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (_isShopping) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_budgetFocus);
                              } else {
                                FocusScope.of(context).unfocus();
                              }
                            },
                            controller: _productDescriptionController,
                            label: _isShopping
                                ? l10n.productDetails
                                : l10n.packageDetails,
                            validator: (v) {
                              final text = v?.trim() ?? '';
                              if (text.isEmpty) {
                                return l10n.pleaseEnterProductDescription;
                              }
                              if (text.length < 10) {
                                return l10n.tooShort;
                              }
                              return null;
                            },
                          ),
                          if (_isShopping) ...[
                            const SizedBox(height: 16),
                            AppTextFormField(
                              focusNode: _budgetFocus,
                              textInputAction: TextInputAction.done,
                              controller: _budgetController,
                              label: l10n.budget,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (!_isShopping) return null;
                                if (v == null || v.trim().isEmpty || v == '0') {
                                  return l10n.pleaseEnterBudget;
                                }
                                if (double.tryParse(v) == null) {
                                  return l10n.pleaseEnterValidNumber;
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          ProductImagePicker(
                            isRequired: !_isShopping,
                            productImage: _productImage,
                            onImagePicked: (file) =>
                                setState(() => _productImage = file),
                          ),
                          const SizedBox(height: 24),
                          _buildNearMeCheckbox(l10n),
                          const SizedBox(height: 16),
                          _buildRouteSection(l10n),
                          const SizedBox(height: 24),
                          if (shippingFee != null) ...[
                            _buildFeeAndPaymentRow(
                              l10n,
                              shippingFee,
                              isOverBudget,
                            ),
                            const SizedBox(height: 24),
                          ] else if (_isShopping && !isOverBudget) ...[
                            _buildPaymentToggle(),
                            const SizedBox(height: 24),
                          ],
                          CouponSection(
                            couponController: _couponController,
                            couponFocus: _couponFocus,
                            appliedCoupon: _appliedCoupon,
                            couponValidating: _couponValidating,
                            onValidate: _validateCoupon,
                            onRemove: _removeCoupon,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: BlocBuilder<OrderCubit, OrderState>(
                        buildWhen: (_, s) =>
                            s is OrderOperationLoading ||
                            s is OrdersLoaded ||
                            s is OrderError ||
                            s is OrderSuccess,
                        builder: (context, state) {
                          return AppCustomButton(
                            onPressed: _submit,
                            text: l10n.confirm,
                            isLoading: state is OrderOperationLoading,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Insufficient Balance Bottom Sheet ─────────────────────────────────────────

class _InsufficientBalanceSheet extends StatelessWidget {
  final double currentBalance;
  final double requiredAmount;
  final double shortfall;
  final bool isShopping;
  final AppLocalizations l10n;
  final VoidCallback onTopUp;

  const _InsufficientBalanceSheet({
    required this.currentBalance,
    required this.requiredAmount,
    required this.shortfall,
    required this.isShopping,
    required this.l10n,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 32,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.insufficientBalance,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isShopping
                ? l10n.insufficientBalanceShoppingDesc
                : l10n.insufficientBalanceShippingDesc,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _BalanceRow(
                  label: l10n.currentBalance,
                  amount: currentBalance,
                  egpLabel: l10n.egp,
                  color: Colors.green.shade700,
                  icon: Icons.account_balance_wallet,
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _BalanceRow(
                  label: l10n.requiredAmount,
                  amount: requiredAmount,
                  egpLabel: l10n.egp,
                  color: Colors.blue.shade700,
                  icon: Icons.receipt_long_outlined,
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _BalanceRow(
                  label: l10n.shortfall,
                  amount: shortfall,
                  egpLabel: l10n.egp,
                  color: Colors.red.shade700,
                  icon: Icons.arrow_downward_rounded,
                  highlight: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTopUp,
              icon: const Icon(Icons.add_card_rounded),
              label: Text(
                l10n.topUpNow,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.notNow,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final double amount;
  final String egpLabel;
  final Color color;
  final IconData icon;
  final bool highlight;

  const _BalanceRow({
    required this.label,
    required this.amount,
    required this.egpLabel,
    required this.color,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: highlight
          ? BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} $egpLabel',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildPinIcon({
  required IconData icon,
  required Color color,
  required Color bgColor,
  bool warning = false,
}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      if (warning)
        Positioned(
          right: -3,
          top: -3,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              size: 9,
              color: Colors.white,
            ),
          ),
        ),
    ],
  );
}

class _VerticalDashedLinePainter extends CustomPainter {
  final Color color;

  const _VerticalDashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashH = 4.0;
    const gap = 4.0;
    double y = 0;
    final x = size.width / 2;

    while (y < size.height) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + dashH).clamp(0, size.height)),
        paint,
      );
      y += dashH + gap;
    }
  }

  @override
  bool shouldRepaint(_VerticalDashedLinePainter old) => old.color != color;
}
