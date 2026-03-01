import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';
import 'package:tawreedat_go/core/utils/app_dynamic_settings.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/sheets/create_order_sheet/select_address.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';

import '../../../../../../core/utils/calculate_distance.dart';
import '../../../../../../core/widgets/custom_button.dart';
import '../../../../../../core/widgets/text_form.dart';
import '../../../../../addresses/data/models/address_model.dart';
import '../../../../../addresses/manager/address_cubit.dart';
import '../../../../../addresses/manager/address_states.dart';
import '../../../../data/models/order_model.dart';
import '../../../../manager/order_cubit.dart';
import '../../../../manager/order_states.dart';
import 'coupon_section.dart';
import 'product_image_picker.dart';
import 'toggle_tab.dart';

class CreateOrderBottomSheet extends StatefulWidget {
  const CreateOrderBottomSheet({super.key});

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

  // Coupon state
  CouponValid? _appliedCoupon;
  bool _couponValidating = false;

  late final AddressCubit _initCubit;

  @override
  void initState() {
    super.initState();
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

  // ── Shipping Fee ───────────────────────────────────────────────────────────
  static final double _feePerKm = double.tryParse(AppSettings.delivery_price_for_each_1km??'0') ?? 10;
  static final double _minFee = double.tryParse(AppSettings.min_delivery_fee??'0') ?? 30;

  Widget _buildShippingFeeEstimate() {
    if (_pickupAddress == null || _deliveryAddress == null) {
      return const SizedBox.shrink();
    }

    final distanceInMeters = calculateDistance(
      double.parse(_pickupAddress!.addressLat),
      double.parse(_pickupAddress!.addressLong),
      double.parse(_deliveryAddress!.addressLat),
      double.parse(_deliveryAddress!.addressLong),
    );

    final distanceKm = distanceInMeters / 1000;
    final calculatedFee = distanceKm * _feePerKm;
    final fee = calculatedFee < _minFee ? _minFee : calculatedFee;

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
          Icon(Icons.local_shipping_outlined, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.estimatedShippingFee,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${fee.toStringAsFixed(2)} ${AppLocalizations.of(context)!.egp}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (!_isShopping && _productImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tapToSelectImage),
          ),
        );
        return;
      }

      if (_pickupAddress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pleaseSelectLocation),
          ),
        );
        return;
      }
      if (_deliveryAddress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pleaseSelectLocation),
          ),
        );
        return;
      }

      final distance = calculateDistance(
        double.parse(_pickupAddress!.addressLat),
        double.parse(_pickupAddress!.addressLong),
        double.parse(_deliveryAddress!.addressLat),
        double.parse(_deliveryAddress!.addressLong),
      );

      if (distance <
          (double.tryParse(AppSettings.min_delivery_distance ?? '1') ?? 1) *
              1000) {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.distanceTooClose,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
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
          pickupAreaId: _pickupAddress!.areaId,
          pickupAddressDescription: _pickupAddress!.detailedAddress,
          pickupLat: _pickupAddress!.addressLat,
          pickupLong: _pickupAddress!.addressLong,
          deliveryAreaId: _deliveryAddress!.areaId,
          deliveryAddressDescription: _deliveryAddress!.detailedAddress,
          deliveryLat: _deliveryAddress!.addressLat,
          deliveryLong: _deliveryAddress!.addressLong,
        ),
      );
    }
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
    final color = isPickup ? Colors.green : Colors.blue;
    final icon = isPickup ? Icons.store_outlined : Icons.location_on;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                color: address == null
                    ? Colors.red.shade200
                    : color.withOpacity(0.4),
              ),
              borderRadius: BorderRadius.circular(8),
              color: address == null ? null : color.withOpacity(0.05),
            ),
            child: Row(
              children: [
                Icon(icon, color: address == null ? Colors.grey : color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    address?.displayAddress ?? label,
                    style: TextStyle(
                      color: address == null ? Colors.grey : Colors.black87,
                    ),
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
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
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
                              FocusScope.of(context).requestFocus(_budgetFocus);
                            } else {
                              FocusScope.of(context).unfocus();
                            }
                          },
                          controller: _productDescriptionController,
                          label: l10n.productDetails,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter product description'
                              : null,
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
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter budget';
                              }
                              if (double.tryParse(v) == null) {
                                return 'Please enter a valid number';
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
                        _buildAddressTile(
                          label: l10n.pickupLocation,
                          address: _pickupAddress,
                          onTap: _selectPickupAddress,
                          isPickup: true,
                        ),
                        const SizedBox(height: 24),
                        _buildAddressTile(
                          label: l10n.deliveryLocation,
                          address: _deliveryAddress,
                          onTap: _selectDeliveryAddress,
                          isPickup: false,
                        ),
                        // ── Shipping Fee Estimate ──────────────────────────
                        const SizedBox(height: 12),
                        _buildShippingFeeEstimate(),
                        const SizedBox(height: 24),
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
    );
  }
}
