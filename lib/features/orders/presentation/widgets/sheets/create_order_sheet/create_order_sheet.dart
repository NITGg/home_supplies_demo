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
import '../../../../../../core/utils/logger.dart';
import '../../../../../../core/widgets/custom_button.dart';
import '../../../../../../core/widgets/text_form.dart';
import '../../../../../addresses/data/models/address_model.dart';
import '../../../../../addresses/data/models/governorate_model.dart';
import '../../../../../addresses/manager/address_cubit.dart';
import '../../../../../addresses/manager/address_states.dart';
import '../../../../../auth/manager/profile_cubit.dart';
import '../../../../../wallet/manager/wallet_cubit.dart';
import '../../../../../wallet/manager/wallet_state.dart';
import '../../../../data/models/draft_model.dart';
import '../../../../data/models/order_model.dart';
import '../../../../manager/order_cubit.dart';
import '../../../../manager/order_states.dart';
import 'insufficient_balance_sheet.dart';
import 'pin_icon.dart';
import 'product_image_picker.dart';
import 'toggle_tab.dart';
import 'vertical_dashed_line_painter.dart';

class CreateOrderBottomSheet extends StatefulWidget {
  final GovernoratesResponse governorates;
  final double? walletBalance;

  // final String? initialCouponCode;

  const CreateOrderBottomSheet({
    super.key,
    required this.governorates,
    this.walletBalance,
    // this.initialCouponCode,
  });

  @override
  State<CreateOrderBottomSheet> createState() => _CreateOrderBottomSheetState();
}

class _CreateOrderBottomSheetState extends State<CreateOrderBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _productDescriptionFocus = FocusNode();
  final FocusNode _budgetFocus = FocusNode();

  // final FocusNode _couponFocus = FocusNode();

  final _productDescriptionController = TextEditingController();
  final _budgetController = TextEditingController();

  // final _couponController = TextEditingController();

  Address? _pickupAddress;
  Address? _deliveryAddress;
  File? _productImage;

  bool _isShopping = true;
  String _paymentMethod = 'CASH';
  bool _pickupNearMe = false;

  DistanceResult? _distanceResult;
  bool _fetchingDistance = false;

  // CouponValid? _appliedCoupon;
  // bool _couponValidating = false;

  late double _walletBalance;
  late final AddressCubit _initCubit;

  // ── Life-cycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    context.read<WalletCubit>().fetchWalletData();
    _walletBalance = widget.walletBalance ?? 0.0;
    _initCubit = AddressCubit();

    // ── Restore draft ──────────────────────────────────────────────────────── // ← DRAFT
    _productDescriptionController.text =
        CreateOrderDraft.productDescription; // ← DRAFT
    _budgetController.text = CreateOrderDraft.budget; // ← DRAFT
    // _couponController.text = CreateOrderDraft.couponCode; // ← DRAFT
    _pickupAddress = CreateOrderDraft.pickupAddress; // ← DRAFT
    _deliveryAddress = CreateOrderDraft.deliveryAddress; // ← DRAFT
    _isShopping = CreateOrderDraft.isShopping; // ← DRAFT
    _paymentMethod = CreateOrderDraft.paymentMethod; // ← DRAFT
    _pickupNearMe = CreateOrderDraft.pickupNearMe; // ← DRAFT
    // _appliedCoupon = CreateOrderDraft.appliedCoupon; // ← DRAFT

    // ── Wire up listeners to keep draft in sync ────────────────────────────── // ← DRAFT
    _productDescriptionController.addListener(_syncDraft); // ← DRAFT
    _budgetController.addListener(() {
      // ← DRAFT
      setState(() {}); // (already existed for rebuild)
      _syncDraft(); // ← DRAFT
    });
    // _couponController.addListener(_syncDraft); // ← DRAFT

    _preloadDefaultDelivery();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Re-fetch distance if we restored both addresses from the draft.        // ← DRAFT
      if (_effectivePickup != null && _deliveryAddress != null) {
        // ← DRAFT
        _fetchDistanceIfReady(); // ← DRAFT
      } // ← DRAFT

      if (!mounted) return;
      if (context.read<ProfileCubit>().currentProfile?.roleId == 4) return;

      // // Only auto-fill coupon when the draft doesn't already have one.         // ← DRAFT
      // if (_couponController.text.isEmpty) {
      //   // ← DRAFT
      //   final code = widget.initialCouponCode?.isNotEmpty == true
      //       ? widget.initialCouponCode
      //       : await context.read<CouponCubit>().getOrFetchFirstOrderCoupon();
      //
      //   if (!mounted || code == null || code.isEmpty) return;
      //   _couponController.text = code;
      //   _validateCoupon();
      // } else if (_appliedCoupon == null && _couponController.text.isNotEmpty) {
      //   // ← DRAFT
      //   // Coupon text was restored but validation state was lost — re-validate. // ← DRAFT
      //   _validateCoupon(); // ← DRAFT
      // }
    });
  }

  // ── Sync all current state into the draft ─────────────────────────────────
  void _syncDraft() {
    // ← DRAFT
    CreateOrderDraft.productDescription = _productDescriptionController.text;
    CreateOrderDraft.budget = _budgetController.text;
    // CreateOrderDraft.couponCode = _couponController.text;
    CreateOrderDraft.pickupAddress = _pickupAddress;
    CreateOrderDraft.deliveryAddress = _deliveryAddress;
    CreateOrderDraft.isShopping = _isShopping;
    CreateOrderDraft.paymentMethod = _paymentMethod;
    CreateOrderDraft.pickupNearMe = _pickupNearMe;
    // CreateOrderDraft.appliedCoupon = _appliedCoupon;
  }

  Future<void> _preloadDefaultDelivery() async {
    _initCubit.stream.listen((state) {
      if (!mounted) return;
      if (state is AddressesLoaded && state.addresses.isNotEmpty) {
        final defaultAddr = state.addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => state.addresses.first,
        );
        // Only use the preloaded default when the draft has no delivery address. // ← DRAFT
        if (_deliveryAddress == null) {
          // ← DRAFT (unchanged logic, but now respects restored draft)
          setState(() => _deliveryAddress = defaultAddr);
          _fetchDistanceIfReady();
        }
      }
    });
    await _initCubit.loadAddresses();
  }

  @override
  void dispose() {
    _syncDraft(); // ← DRAFT — persist latest state before widget tree tears down
    _initCubit.close();
    _productDescriptionController.dispose();
    _budgetController.dispose();
    // _couponController.dispose();
    _productDescriptionFocus.dispose();
    _budgetFocus.dispose();
    // _couponFocus.dispose();
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

      dLog(
        '📏 [Distance] ${result.distanceMeters} m  '
        '⏱ ${result.durationSeconds} s  '
        '(${result.provider})',
      );

      if (mounted) setState(() => _distanceResult = result);
    } catch (e) {
      dLog('❌ [Distance] fetch failed: $e');
      if (mounted) setState(() => _distanceResult = null);
    } finally {
      if (mounted) setState(() => _fetchingDistance = false);
    }
  }

  // ── Fee calculation ────────────────────────────────────────────────────────

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

    dLog('🚚 [Shipping] dist=${distanceMeters}m  fee=$finalFee EGP');
    return finalFee;
  }

  double _requiredWalletAmount() {
    final rawFee = _calculateShippingFee() ?? 0.0;

    double fee = rawFee;
    // if (_appliedCoupon != null && _appliedCoupon!.isDeliveryFeeDiscount) {
    //   if (_appliedCoupon!.isPercentDiscount &&
    //       _appliedCoupon!.discountValue != null) {
    //     fee = (rawFee - (rawFee * _appliedCoupon!.discountValue! / 100)).clamp(
    //       0,
    //       double.infinity,
    //     );
    //   } else if (_appliedCoupon!.isFixedDiscount &&
    //       _appliedCoupon!.discountValue != null) {
    //     fee = (rawFee - _appliedCoupon!.discountValue!).clamp(
    //       0,
    //       double.infinity,
    //     );
    //   }
    // }

    if (_isShopping) {
      final budget = double.tryParse(_budgetController.text.trim()) ?? 0.0;
      return fee + budget;
    }
    return fee;
  }

  // ── Coupon ─────────────────────────────────────────────────────────────────

  // Future<void> _validateCoupon() async {
  //   final code = _couponController.text.trim();
  //   if (code.isEmpty) return;
  //
  //   setState(() {
  //     _couponValidating = true;
  //     _appliedCoupon = null;
  //   });
  //
  //   context.read<OrderCubit>().validateCoupon(code,customOrder: true);
  // }

  // void _removeCoupon() {
  //   setState(() {
  //     _appliedCoupon = null;
  //     _couponController.clear();
  //   });
  //   _syncDraft(); // ← DRAFT
  // }

  // ── Address sheet ──────────────────────────────────────────────────────────

  Future<void> _selectPickupAddress() async {
    final result = await _openAddressSheet(
      title: AppLocalizations.of(context)!.pickupLocation,
      isPickup: true,
    );
    if (result != null && mounted) {
      setState(() => _pickupAddress = result);
      _syncDraft(); // ← DRAFT
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
      _syncDraft(); // ← DRAFT
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
            SizedBox(
              width: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (!_pickupNearMe)
                      buildPinIcon(
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
                            painter: VerticalDashedLinePainter(
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    ),
                    buildPinIcon(
                      icon: Icons.location_on,
                      color: const Color(0xFF185FA5),
                      bgColor: const Color(0xFFE6F1FB),
                      warning: deliveryOutOfBounds,
                    ),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, color: Colors.grey.shade200),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                        onTap: () {
                          setState(() => _paymentMethod = 'CASH');
                          _syncDraft(); // ← DRAFT
                        },
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
                        onTap: () {
                          setState(() => _paymentMethod = 'WALLET');
                          _syncDraft(); // ← DRAFT
                        },
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
    // double? discountedFee;
    // if (_appliedCoupon != null && _appliedCoupon!.isDeliveryFeeDiscount) {
    //   if (_appliedCoupon!.isPercentDiscount &&
    //       _appliedCoupon!.discountValue != null) {
    //     discountedFee = (fee - (fee * _appliedCoupon!.discountValue! / 100))
    //         .clamp(0, double.infinity);
    //   } else if (_appliedCoupon!.isFixedDiscount &&
    //       _appliedCoupon!.discountValue != null) {
    //     discountedFee = (fee - _appliedCoupon!.discountValue!).clamp(
    //       0,
    //       double.infinity,
    //     );
    //   }
    // }
    //
    // final bool hasFeeDiscount = discountedFee != null;

    // final feeChip = Container(
    //   height: 56,
    //   padding: const EdgeInsets.symmetric(horizontal: 12),
    //   decoration: BoxDecoration(
    //     color: hasFeeDiscount
    //         ? Colors.green.shade50
    //         : AppColors.kSecondaryColor.withOpacity(0.08),
    //     borderRadius: BorderRadius.circular(14),
    //     border: Border.all(
    //       color: hasFeeDiscount
    //           ? Colors.green.shade300
    //           : AppColors.kSecondaryColor.withOpacity(0.25),
    //     ),
    //   ),
    //   child: Column(
    //     mainAxisAlignment: MainAxisAlignment.center,
    //     crossAxisAlignment: CrossAxisAlignment.center,
    //     children: [
    //       Text(
    //         l10n.estimatedShippingFee,
    //         style: TextStyle(
    //           fontSize: 10,
    //           color: hasFeeDiscount
    //               ? Colors.green.shade700
    //               : AppColors.kSecondaryColor.withOpacity(0.8),
    //           fontWeight: FontWeight.w500,
    //         ),
    //       ),
    //       const SizedBox(height: 3),
    //       if (hasFeeDiscount)
    //         Row(
    //           mainAxisAlignment: MainAxisAlignment.center,
    //           mainAxisSize: MainAxisSize.min,
    //           children: [
    //             Text(
    //               '${fee.toInt()} ${l10n.egp}',
    //               style: TextStyle(
    //                 fontSize: 11,
    //                 fontWeight: FontWeight.w500,
    //                 color: Colors.red.shade400,
    //                 decoration: TextDecoration.lineThrough,
    //                 decorationColor: Colors.red.shade400,
    //               ),
    //             ),
    //             const SizedBox(width: 6),
    //             Text(
    //               '${discountedFee.toInt()} ${l10n.egp}',
    //               style: TextStyle(
    //                 fontSize: 13,
    //                 fontWeight: FontWeight.bold,
    //                 color: Colors.green.shade700,
    //               ),
    //             ),
    //           ],
    //         )
    //       else
    //         Text(
    //           textAlign: TextAlign.center,
    //           '${fee.toInt()} ${l10n.egp}',
    //           style: TextStyle(
    //             fontSize: 13,
    //             fontWeight: FontWeight.bold,
    //             color: AppColors.kSecondaryColor,
    //           ),
    //         ),
    //     ],
    //   ),
    // );

    if (!_isShopping || isOverBudget) return SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // feeChip,
        // const SizedBox(width: 10),
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
        return InsufficientBalanceSheet(
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
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context)!.tapToSelectImage,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
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
        orderItems: [],
        productDescription: _productDescriptionController.text.trim(),
        productImageFile: _productImage,
        budget: _isShopping
            ? (double.parse(_budgetController.text.trim()) * 100)
                  .round()
                  .toString()
            : '1',
        //1 means shipping
        pickupAreaId: effectivePickup.areaId,
        pickupAddressDescription: effectivePickup.detailedAddress,
        pickupLat: effectivePickup.addressLat,
        pickupLong: effectivePickup.addressLong,
        deliveryAreaId: _deliveryAddress!.areaId,
        deliveryAddressDescription: _deliveryAddress!.detailedAddress,
        deliveryLat: _deliveryAddress!.addressLat,
        deliveryLong: _deliveryAddress!.addressLong,
      ),
      estimatedDeliveryFee: ((_calculateShippingFee() ?? 0) * 100).toString(),
      _isShopping ? _paymentMethod : 'WALLET',
      // couponCode: _appliedCoupon?.code,
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
            onTap: () {
              setState(() => _isShopping = true);
              _syncDraft(); // ← DRAFT
            },
          ),
          ToggleTab(
            label: l10n.shipping,
            selected: !_isShopping,
            onTap: () {
              setState(() => _isShopping = false);
              _syncDraft(); // ← DRAFT
            },
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
        _syncDraft(); // ← DRAFT
        _fetchDistanceIfReady();
      },
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _pickupNearMe,
              activeColor: AppColors.kPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (val) {
                setState(() {
                  _pickupNearMe = val ?? false;
                  if (_pickupNearMe) _pickupAddress = null;
                });
                _syncDraft(); // ← DRAFT
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
          // if (state is CouponValidating) {
          //   if (!_couponValidating) setState(() => _couponValidating = true);
          // } else if (state is CouponRedeemed) {
          //   setState(() {
          //     _couponValidating = false;
          //     if (state.coupon != null) _appliedCoupon = state.coupon;
          //   });
          //   _syncDraft(); // ← DRAFT
          //   Fluttertoast.showToast(
          //     msg: l10n.couponRedeemed,
          //     toastLength: Toast.LENGTH_SHORT,
          //     gravity: ToastGravity.BOTTOM,
          //     backgroundColor: Colors.green.shade700,
          //   );
          // } else if (state is CouponInvalid) {
          //   setState(() => _couponValidating = false);
          //   Fluttertoast.showToast(
          //     msg: state.message,
          //     toastLength: Toast.LENGTH_LONG,
          //     gravity: ToastGravity.BOTTOM,
          //     backgroundColor: Colors.red,
          //     textColor: Colors.white,
          //   );
          // } else if (state is CouponRedeemError) {
          //   setState(() => _couponValidating = false);
          //   Fluttertoast.showToast(
          //     msg: state.message,
          //     toastLength: Toast.LENGTH_LONG,
          //     gravity: ToastGravity.BOTTOM,
          //     backgroundColor: Colors.orange,
          //     textColor: Colors.white,
          //   );
          // } else
          if (state is OrderSuccess) {
            CreateOrderDraft.clear(); // ← DRAFT — wipe draft after a successful order
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
                          // CouponSection(
                          //   couponController: _couponController,
                          //   couponFocus: _couponFocus,
                          //   appliedCoupon: _appliedCoupon,
                          //   couponValidating: _couponValidating,
                          //   onValidate: _validateCoupon,
                          //   onRemove: _removeCoupon,
                          // ),
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
                            isLoading:
                            _distanceResult == null || (!_pickupNearMe && _pickupAddress == null) ||
                                state is OrderOperationLoading,
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
