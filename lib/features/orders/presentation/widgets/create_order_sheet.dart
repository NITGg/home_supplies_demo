import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../addresses/data/models/address_model.dart';
import '../../../addresses/manager/address_cubit.dart';
import '../../../addresses/manager/address_states.dart';
import '../../../addresses/manager/location_cubit.dart';
import '../../../addresses/presentation/address_form_sheet.dart';
import '../../data/models/order_model.dart';
import '../../manager/order_cubit.dart';
import '../../manager/order_states.dart';

class CreateOrderBottomSheet extends StatefulWidget {
  const CreateOrderBottomSheet({super.key});

  @override
  State<CreateOrderBottomSheet> createState() => _CreateOrderBottomSheetState();
}

class _CreateOrderBottomSheetState extends State<CreateOrderBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _productDescriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Address? _pickupAddress;
  Address? _deliveryAddress;
  File? _productImage;

  /// Dedicated cubit that fetches addresses once to pre-fill default delivery.
  late final AddressCubit _initCubit;

  @override
  void initState() {
    super.initState();
    _initCubit = AddressCubit();
    _preloadDefaultDelivery();
  }

  /// Loads saved addresses and, if one is marked default (or falls back to
  /// the first), pre-fills the delivery address field.
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
    super.dispose();
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
        child: _AddressSelectionSheet(title: title, isPickup: isPickup),
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  void _submit() {
    if (_formKey.currentState!.validate()) {
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

      context.read<OrderCubit>().createOrder(
        Order(
          productDescription: _productDescriptionController.text.trim(),
          productImageFile: _productImage,
          budget: _budgetController.text.trim(),
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

  // ── Image picker ───────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (img != null && mounted) setState(() => _productImage = File(img.path));
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.productImageOptional,
          style: AppTextStyles.regular14,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: _productImage != null
                    ? AppColors.kPrimaryColor
                    : Colors.grey.shade300,
                width: _productImage != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: _productImage != null ? Colors.white : Colors.grey.shade50,
            ),
            child: _productImage != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _productImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.kPrimaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_photo_alternate,
                          size: 32,
                          color: AppColors.kPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.tapToSelectImage,
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG or PNG (max 1MB)',
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ── Address tile ───────────────────────────────────────────────────────────

  Widget _buildAddressTile({
    required String label,
    required Address? address,
    required VoidCallback onTap,
    required bool isPickup,
  }) {
    final color = isPickup ? Colors.green : Colors.blue;
    final icon = isPickup ? Icons.my_location : Icons.location_on;

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
    return BlocListener<OrderCubit, OrderState>(
      listenWhen: (_, s) => s is OrderSuccess || s is OrderError,
      listener: (context, state) {
        if (state is OrderSuccess) {
          Navigator.pop(context, state.order);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)!.created}: ${state.order.orderNumber}',
              ),
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
                          AppLocalizations.of(context)!.newOrder,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
                          controller: _productDescriptionController,
                          label: AppLocalizations.of(context)!.productDetails,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter product description'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        AppTextFormField(
                          controller: _budgetController,
                          label: AppLocalizations.of(context)!.budget,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter budget';
                            }
                            if (double.tryParse(v) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildImagePicker(),
                        const SizedBox(height: 24),
                        _buildAddressTile(
                          label: AppLocalizations.of(context)!.pickupLocation,
                          address: _pickupAddress,
                          onTap: _selectPickupAddress,
                          isPickup: true,
                        ),
                        const SizedBox(height: 24),
                        _buildAddressTile(
                          label: AppLocalizations.of(context)!.deliveryLocation,
                          address: _deliveryAddress,
                          onTap: _selectDeliveryAddress,
                          isPickup: false,
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
                          text: AppLocalizations.of(context)!.confirm,
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

// ─────────────────────────────────────────────────────────────────────────────
// Inner address-selection sheet (pickup OR delivery within create order flow)
// ─────────────────────────────────────────────────────────────────────────────

class _AddressSelectionSheet extends StatefulWidget {
  final String title;
  final bool isPickup;

  const _AddressSelectionSheet({required this.title, required this.isPickup});

  @override
  State<_AddressSelectionSheet> createState() => _AddressSelectionSheetState();
}

class _AddressSelectionSheetState extends State<_AddressSelectionSheet> {
  @override
  void initState() {
    super.initState();
    context.read<AddressCubit>().loadAddresses();
  }

  Future<void> _showAddressForm({required bool saveAddress}) async {
    final addressCubit = context.read<AddressCubit>();

    final result = await showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: addressCubit),
          BlocProvider(create: (_) => LocationCubit()),
        ],
        child: AddressFormBottomSheet(saveAddress: saveAddress),
      ),
    );

    if (result != null && mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
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
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppCustomButton(
                  onPressed: () => _showAddressForm(saveAddress: true),
                  text: AppLocalizations.of(context)!.addAddress,
                  isSecondary: true,
                ),
                const SizedBox(height: 8),
                AppCustomButton(
                  onPressed: () => _showAddressForm(saveAddress: false),
                  text: AppLocalizations.of(context)!.oneTimeAddress,
                  isSecondary: true,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<AddressCubit, AddressState>(
              builder: (context, state) {
                if (state is AddressLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is AddressError) {
                  return Center(child: Text(state.message));
                }
                if (state is AddressesLoaded) {
                  if (state.addresses.isEmpty) {
                    return const Center(child: Text('No saved addresses'));
                  }

                  // For the delivery sheet, highlight the default address.
                  final defaultId = !widget.isPickup
                      ? state.addresses
                            .firstWhere(
                              (a) => a.isDefault,
                              orElse: () => state.addresses.first,
                            )
                            .id
                      : null;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.addresses.length,
                    itemBuilder: (_, index) {
                      final address = state.addresses[index];
                      final isDefault = address.id == defaultId;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: isDefault
                              ? BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          leading: Icon(
                            widget.isPickup
                                ? Icons.my_location
                                : Icons.location_on,
                            color: widget.isPickup ? Colors.green : Colors.blue,
                          ),
                          title: Text(address.displayAddress),
                          subtitle: isDefault
                              ? Text(
                                  'Default',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          onTap: () => Navigator.pop(context, address),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}
