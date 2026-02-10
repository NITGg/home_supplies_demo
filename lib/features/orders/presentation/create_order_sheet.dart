import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/text_form.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../addresses/data/models/address_model.dart';
import '../../addresses/manager/address_cubit.dart';
import '../../addresses/manager/address_states.dart';
import '../../addresses/manager/location_cubit.dart';
import '../../addresses/presentation/address_form_sheet.dart';
import '../data/models/order_model.dart';
import '../manager/order_cubit.dart';
import '../manager/order_states.dart';

class CreateOrderBottomSheet extends StatefulWidget {
  const CreateOrderBottomSheet({super.key});

  @override
  State<CreateOrderBottomSheet> createState() => _CreateOrderBottomSheetState();
}

class _CreateOrderBottomSheetState extends State<CreateOrderBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _productDescriptionController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Address? _pickupAddress;
  Address? _deliveryAddress;
  File? _productImage;

  @override
  void dispose() {
    _productDescriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      setState(() {
        _productImage = File(image.path);
      });
    }
  }

  Future<void> _selectPickupAddress() async {
    final result = await _showAddressOptions(
      context,
      'Select Pickup Address',
      isPickup: true,
    );
    if (result != null && mounted) {
      setState(() => _pickupAddress = result);
    }
  }

  Future<void> _selectDeliveryAddress() async {
    final result = await _showAddressOptions(
      context,
      'Select Delivery Address',
      isPickup: false,
    );
    if (result != null && mounted) {
      setState(() => _deliveryAddress = result);
    }
  }

  Future<Address?> _showAddressOptions(
      BuildContext context,
      String title, {
        required bool isPickup,
      }) async {
    return await showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider(
        create: (_) => AddressCubit(),
        child: _AddressSelectionSheet(
          title: title,
          isPickup: isPickup,
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_pickupAddress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a pickup address')),
        );
        return;
      }

      if (_deliveryAddress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a delivery address')),
        );
        return;
      }

      final order = Order(
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
      );

      context.read<OrderCubit>().createOrder(order);
    }
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Image (Optional)',
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
                  'Tap to select image',
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderCubit, OrderState>(
      listener: (context, state) {
        if (state is OrderSuccess) {
          Navigator.pop(context, state.order);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order created: ${state.order.orderNumber}'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is OrderError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
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
                // Handle
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
                      const Expanded(
                        child: Text(
                          'Create Order',
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
                // Form
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        AppTextFormField(
                          controller: _productDescriptionController,
                          label: 'Product Description',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter product description';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextFormField(
                          controller: _budgetController,
                          label: 'Budget',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter budget';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        // const SizedBox(height: 16),
                        // _buildImagePicker(),
                        const SizedBox(height: 24),
                        // Pickup Address
                        const Text(
                          'Pickup Address',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectPickupAddress,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _pickupAddress == null
                                    ? Colors.red.shade200
                                    : Colors.green.shade300,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: _pickupAddress == null
                                  ? null
                                  : Colors.green.shade50,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.my_location,
                                  color: _pickupAddress == null
                                      ? Colors.grey
                                      : Colors.green,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _pickupAddress?.displayAddress ??
                                        'Select pickup address',
                                    style: TextStyle(
                                      color: _pickupAddress == null
                                          ? Colors.grey
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Delivery Address
                        const Text(
                          'Delivery Address',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectDeliveryAddress,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _deliveryAddress == null
                                    ? Colors.red.shade200
                                    : Colors.blue.shade300,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: _deliveryAddress == null
                                  ? null
                                  : Colors.blue.shade50,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: _deliveryAddress == null
                                      ? Colors.grey
                                      : Colors.blue,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _deliveryAddress?.displayAddress ??
                                        'Select delivery address',
                                    style: TextStyle(
                                      color: _deliveryAddress == null
                                          ? Colors.grey
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: BlocBuilder<OrderCubit, OrderState>(
                      builder: (context, state) {
                        final isLoading = state is OrderLoading;
                        return AppCustomButton(
                          onPressed: isLoading ? () {} : _submit,
                          text: 'Create Order',
                          isLoading: isLoading,
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

// Simple address selection sheet
class _AddressSelectionSheet extends StatefulWidget {
  final String title;
  final bool isPickup;

  const _AddressSelectionSheet({
    required this.title,
    required this.isPickup,
  });

  @override
  State<_AddressSelectionSheet> createState() => _AddressSelectionSheetState();
}

class _AddressSelectionSheetState extends State<_AddressSelectionSheet> {
  @override
  void initState() {
    super.initState();
    context.read<AddressCubit>().loadAddresses();
  }

  Future<void> _showAddAddressSheet({bool saveAddress = true}) async {
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

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
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
          // Add new address buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppCustomButton(
                  onPressed: () => _showAddAddressSheet(saveAddress: true),
                  text: 'Add & Save Address',
                  isSecondary: true,
                ),
                const SizedBox(height: 8),
                AppCustomButton(
                  onPressed: () => _showAddAddressSheet(saveAddress: false),
                  text: 'Use Address (Don\'t Save)',
                  isSecondary: true,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Saved addresses list
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
                    return const Center(
                      child: Text('No saved addresses'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.addresses.length,
                    itemBuilder: (context, index) {
                      final address = state.addresses[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(
                            widget.isPickup
                                ? Icons.my_location
                                : Icons.location_on,
                            color: widget.isPickup ? Colors.green : Colors.blue,
                          ),
                          title: Text(address.displayAddress),
                          subtitle: Text('Area ID: ${address.areaId}'),
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