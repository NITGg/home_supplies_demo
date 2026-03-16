import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';
import 'package:tawreedat_go/core/style/text_styles.dart';
import 'package:tawreedat_go/core/utils/app_dynamic_settings.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/sheets/create_order_sheet/select_address.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';

import '../../../../../../core/utils/area_boundry_validator.dart';
import '../../../../../../core/utils/calculate_distance.dart';
import '../../../../../../core/widgets/custom_button.dart';
import '../../../../../../core/widgets/text_form.dart';
import '../../../../../addresses/data/models/address_model.dart';
import '../../../../../addresses/data/models/governorate_model.dart';
import '../../../../../addresses/manager/address_cubit.dart';
import '../../../../../addresses/manager/address_states.dart';
import '../../../../../wallet/manager/wallet_cubit.dart';
import '../../../../../wallet/manager/wallet_state.dart';
import '../../../../data/models/order_model.dart';
import '../../../../manager/order_cubit.dart';
import '../../../../manager/order_states.dart';
import 'coupon_section.dart';
import 'product_image_picker.dart';
import 'toggle_tab.dart';

class CreateOrderBottomSheet extends StatefulWidget {
  /// Pass the already-loaded governorates response so we can look up area
  /// boundaries without an extra network call.
  final GovernoratesResponse governorates;

  /// Current wallet balance in EGP. Pass null to skip balance checks.
  final double? walletBalance;

  const CreateOrderBottomSheet({
    super.key,
    required this.governorates,
    this.walletBalance,
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
  String _paymentMethod = 'CASH'; // 'CASH' or 'WALLET'

  // Coupon state
  CouponValid? _appliedCoupon;
  bool _couponValidating = false;

  // Wallet balance — mutable so we can refresh after returning from TopUp
  late double _walletBalance;

  late final AddressCubit _initCubit;

  // ── Life-cycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _walletBalance = widget.walletBalance ?? 0.0;
    _initCubit = AddressCubit();
    _preloadDefaultDelivery();
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

  // ── Boundary validation ────────────────────────────────────────────────────

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

  // ── Fee calculation ────────────────────────────────────────────────────────

  /// Calculates the estimated shipping fee in EGP (already ceiled).
  /// Returns null when pickup or delivery address is not set yet.
  double? _calculateShippingFee() {
    if (_pickupAddress == null || _deliveryAddress == null) return null;

    final rawFeePerKm =
        double.tryParse(AppSettings.delivery_price_for_each_1km ?? '0') ?? 1000;
    final rawMinFee =
        double.tryParse(AppSettings.min_delivery_fee ?? '0') ?? 3000;

    final double feePerKm = rawFeePerKm / 100;
    final double minFee = rawMinFee / 100;

    final distanceInMeters = calculateDistance(
      double.parse(_pickupAddress!.addressLat),
      double.parse(_pickupAddress!.addressLong),
      double.parse(_deliveryAddress!.addressLat),
      double.parse(_deliveryAddress!.addressLong),
    );
    final distanceKm = (distanceInMeters / 1000).round();
    final calculatedFee = distanceKm * feePerKm;
    final fee = calculatedFee < minFee ? minFee : calculatedFee;

    return fee.ceilToDouble();
  }

  /// Returns the total wallet amount required for this order in EGP.
  ///
  /// Shopping + wallet → fee + budget
  /// Shipping          → fee only (budget is irrelevant / set to 1 cent)
  double _requiredWalletAmount() {
    final fee = _calculateShippingFee() ?? 0.0;
    if (_isShopping) {
      final budget = double.tryParse(_budgetController.text.trim()) ?? 0.0;
      return fee + budget;
    }
    return fee;
  }

  // ── Wallet balance helpers ─────────────────────────────────────────────────

  /// Tries to read the latest balance from WalletCubit (if it is in the tree
  /// above this sheet) and updates [_walletBalance] accordingly.
  void _tryRefreshWalletBalance() {
    try {
      final cubit = context.read<WalletCubit>();
      final s = cubit.state;
      if (s is WalletLoaded) {
        setState(() => _walletBalance = s.walletData.wallet.balance);
      }
    } catch (_) {
      // WalletCubit not in tree — silently ignore.
    }
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
    if (result != null && mounted) setState(() => _pickupAddress = result);
  }

  Future<void> _selectDeliveryAddress() async {
    final result = await _openAddressSheet(
      title: AppLocalizations.of(context)!.deliveryLocation,
      isPickup: false,
    );
    if (result != null && mounted) setState(() => _deliveryAddress = result);
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

  // ── Shipping fee estimate ──────────────────────────────────────────────────

  Widget _buildShippingFeeEstimate() {
    final fee = _calculateShippingFee();
    if (fee == null) return const SizedBox.shrink();

    log('─── _buildShippingFeeEstimate → fee: $fee EGP ───');

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.kSecondaryColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.estimatedShippingFee,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            '${fee.toInt()} ${AppLocalizations.of(context)!.egp}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
        ],
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
        Text(
          l10n.paymentMethod,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Stack(
            children: [
              // Animated sliding pill
              Directionality(
                textDirection: TextDirection.ltr,
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment:
                  isCash ? Alignment.centerLeft : Alignment.centerRight,
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
              // Tap targets
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
                          label: l10n.cod,
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
              color:
              selected ? AppColors.kSecondaryColor : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: selected
                ? AppTextStyles.bold14
                : AppTextStyles.regular14.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Insufficient balance dialog ────────────────────────────────────────────

  /// Shows a modal bottom-sheet explaining the balance shortfall and offering
  /// a direct link to the Top Up screen. The sheet is left open so all form
  /// data is preserved; balance is refreshed when the user navigates back.
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
            // Navigate to top-up; order sheet stays alive underneath.
            await context.push('/wallet/topup');
            // Back from top-up — refresh balance from cubit if available.
            if (mounted) _tryRefreshWalletBalance();
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.tapToSelectImage)));
      return;
    }

    if (_pickupAddress == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.pleaseSelectLocation)));
      return;
    }

    if (_deliveryAddress == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.pleaseSelectLocation)));
      return;
    }

    // ── Boundary validation ────────────────────────────────────────────────

    if (!_isAddressInArea(_pickupAddress!)) {
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

    // ── Distance validation ────────────────────────────────────────────────

    final distance = calculateDistance(
      double.parse(_pickupAddress!.addressLat),
      double.parse(_pickupAddress!.addressLong),
      double.parse(_deliveryAddress!.addressLat),
      double.parse(_deliveryAddress!.addressLong),
    );

    if (distance <
        (double.tryParse(AppSettings.min_delivery_distance ?? '2') ?? 2) *
            1000) {
      Fluttertoast.showToast(
        msg: l10n.distanceTooClose,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    // ── Wallet balance validation ──────────────────────────────────────────
    // Applies when:
    //   • Shopping and the user chose Wallet as payment method, OR
    //   • Shipping (always deducted from wallet)

    final bool usesWallet = _paymentMethod == 'WALLET' || !_isShopping;

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

    // ── Create order ───────────────────────────────────────────────────────

    context.read<OrderCubit>().createOrder(
      Order(
        productDescription: _productDescriptionController.text.trim(),
        productImageFile: _productImage,
        budget: _isShopping
            ? (double.parse(_budgetController.text.trim()) * 100)
            .round()
            .toString()
            : '1',
        pickupAreaId: _pickupAddress!.areaId,
        pickupAddressDescription: _pickupAddress!.detailedAddress,
        pickupLat: _pickupAddress!.addressLat,
        pickupLong: _pickupAddress!.addressLong,
        deliveryAreaId: _deliveryAddress!.areaId,
        deliveryAddressDescription: _deliveryAddress!.detailedAddress,
        deliveryLat: _deliveryAddress!.addressLat,
        deliveryLong: _deliveryAddress!.addressLong,
      ),
      _isShopping ? _paymentMethod : 'WALLET',
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

  Widget _buildAddressTile({
    required String label,
    required Address? address,
    required VoidCallback onTap,
    required bool isPickup,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final color = isPickup ? Colors.green : Colors.blue;
    final icon = isPickup ? Icons.store_outlined : Icons.location_on;

    final bool outOfBounds = address != null && !_isAddressInArea(address);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (outOfBounds) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: l10n.addressMayBeOutsideArea,
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: outOfBounds
                    ? Colors.orange.shade400
                    : address == null
                    ? Colors.red.shade200
                    : color.withOpacity(0.4),
              ),
              borderRadius: BorderRadius.circular(8),
              color: outOfBounds
                  ? Colors.orange.withOpacity(0.05)
                  : address == null
                  ? null
                  : color.withOpacity(0.05),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: outOfBounds
                      ? Colors.orange
                      : address == null
                      ? Colors.grey
                      : color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address?.displayAddress ?? label,
                        style: TextStyle(
                          color:
                          address == null ? Colors.grey : Colors.black87,
                        ),
                      ),
                      if (outOfBounds) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.addressMayBeOutsideArea,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<OrderCubit, OrderState>(
      listener: (context, state) {
        if (state is CouponValidating || state is CouponRedeeming) {
          if (!_couponValidating) setState(() => _couponValidating = true);
        } else if (state is CouponRedeemed) {
          setState(() {
            _couponValidating = false;
            if (state.coupon != null) _appliedCoupon = state.coupon;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.couponRedeemed),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 3),
            ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.created}: ${state.order.orderNumber}'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is OrderError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
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

                // Wallet balance hint
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
                              ? l10n.walletBalanceHintShopping
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

                // Scrollable body
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Product description
                        AppTextFormField(
                          focusNode: _productDescriptionFocus,
                          textInputAction: _isShopping
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (_isShopping) {
                              FocusScope.of(context)
                                  .requestFocus(_budgetFocus);
                            } else {
                              FocusScope.of(context).unfocus();
                            }
                          },
                          controller: _productDescriptionController,
                          label: _isShopping ? l10n.productDetails: l10n.packageDetails,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? l10n.pleaseEnterProductDescription
                              : null,
                        ),

                        // Budget (shopping only)
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

                        // Image picker
                        ProductImagePicker(
                          isRequired: !_isShopping,
                          productImage: _productImage,
                          onImagePicked: (file) =>
                              setState(() => _productImage = file),
                        ),

                        const SizedBox(height: 24),

                        // Pickup address
                        _buildAddressTile(
                          label: l10n.pickupLocation,
                          address: _pickupAddress,
                          onTap: _selectPickupAddress,
                          isPickup: true,
                        ),

                        const SizedBox(height: 24),

                        // Delivery address
                        _buildAddressTile(
                          label: l10n.deliveryLocation,
                          address: _deliveryAddress,
                          onTap: _selectDeliveryAddress,
                          isPickup: false,
                        ),

                        // Shipping fee estimate
                        _buildShippingFeeEstimate(),

                        const SizedBox(height: 24),
                        if (_isShopping) ...[
                          // Payment method
                          _buildPaymentToggle(),
                          const SizedBox(height: 24),
                        ],

                        // Coupon
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

                // Confirm button
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
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Icon
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

          // Title
          Text(
            l10n.insufficientBalance,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Subtitle — context-aware (shopping vs shipping)
          Text(
            isShopping
                ? l10n.insufficientBalanceShoppingDesc
                : l10n.insufficientBalanceShippingDesc,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // Balance breakdown card
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

          // Top Up button
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

          // Dismiss
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