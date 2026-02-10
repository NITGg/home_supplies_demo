import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/text_form.dart';
import '../../../l10n/app_localizations.dart';

import '../data/models/address_model.dart';
import '../manager/address_cubit.dart';
import '../manager/address_states.dart';
import '../manager/location_cubit.dart';

class AddressFormBottomSheet extends StatefulWidget {
  final Address? address;
  final bool saveAddress;

  const AddressFormBottomSheet({
    super.key,
    this.address,
    this.saveAddress = true,
  });

  @override
  State<AddressFormBottomSheet> createState() => _AddressFormBottomSheetState();
}

class _AddressFormBottomSheetState extends State<AddressFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _detailedAddressController;
  late TextEditingController _latController;
  late TextEditingController _longController;
  late TextEditingController _areaIdController;
  late TextEditingController name;

  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _detailedAddressController =
        TextEditingController(text: widget.address?.detailedAddress);
    _latController = TextEditingController(text: widget.address?.addressLat);
    _longController = TextEditingController(text: widget.address?.addressLong);
    _areaIdController = TextEditingController(
      text: widget.address?.areaId.toString() ?? '1',
    );
    _hasLocation =
    (_latController.text.isNotEmpty && _longController.text.isNotEmpty);
  }

  @override
  void dispose() {
    _detailedAddressController.dispose();
    _latController.dispose();
    _longController.dispose();
    _areaIdController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    context.read<LocationCubit>().getCurrentLocation();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final address = Address(
        name: widget.address?.name,
        isDefault: widget.address?.isDefault ?? false,
        id: widget.address?.id,
        areaId: int.tryParse(_areaIdController.text.trim()) ?? 1,
        addressLat: _latController.text.trim(),
        addressLong: _longController.text.trim(),
        detailedAddress: _detailedAddressController.text.trim(),
      );

      if (widget.saveAddress) {
        // Save to backend
        if (widget.address != null) {
          context.read<AddressCubit>().updateAddress(
            widget.address!.id!,
            address,
          );
        } else {
          context.read<AddressCubit>().createAddress(address);
        }
      } else {
        // Just return the address without saving
        Navigator.pop(context, address);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Listen to LocationCubit for location updates
        BlocListener<LocationCubit, LocationState>(
          listener: (context, state) {
            if (state is LocationLoaded) {
              setState(() {
                _latController.text = state.latitude;
                _longController.text = state.longitude;
                _hasLocation = true;
              });
            }
          },
        ),
        // Listen to AddressCubit for address operations
        if (widget.saveAddress)
          BlocListener<AddressCubit, AddressState>(
            listener: (context, state) {
              if (state is AddressOperationSuccess) {
                Navigator.pop(context, state.address);
              } else if (state is AddressError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
      ],
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.6,
        maxChildSize: 0.9,
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
                      Expanded(
                        child: Text(
                          widget.address != null
                              ? AppLocalizations.of(context)!.edit
                              : AppLocalizations.of(context)!.detailedAddress,
                          style: const TextStyle(
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
                          controller: _detailedAddressController,
                          label: AppLocalizations.of(context)!.detailedAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return AppLocalizations.of(context)!.required;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextFormField(
                          controller: _areaIdController,
                          label: 'Area ID',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return AppLocalizations.of(context)!.required;
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Location Error & Status
                        BlocBuilder<LocationCubit, LocationState>(
                          builder: (context, locationState) {
                            if (locationState is LocationError) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade700,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            locationState.message,
                                            style: TextStyle(
                                              color: Colors.red.shade900,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          GestureDetector(
                                            onTap: () {
                                              context
                                                  .read<LocationCubit>()
                                                  .openLocationSettings();
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.settings,
                                                  size: 16,
                                                  color: Colors.red.shade700,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Open Settings',
                                                  style: TextStyle(
                                                    color: Colors.red.shade700,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        // Location Status and Button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: Column(
                            children: [
                              if (_hasLocation)
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 600),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                          vertical: 10,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius:
                                          BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.green.shade200,
                                            width: 2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: Colors.green.shade700,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green.shade700,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              AppLocalizations.of(context)!
                                                  .locationObtained,
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              BlocBuilder<LocationCubit, LocationState>(
                                builder: (context, locationState) {
                                  final isLoadingLocation =
                                  locationState is LocationLoading;
                                  return AppCustomButton(
                                    isSecondary: true,
                                    onPressed: _getCurrentLocation,
                                    text: AppLocalizations.of(context)!
                                        .useCurrentLocation,
                                    isLoading: isLoadingLocation,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Debug: Show coordinates
                        if (_hasLocation)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location Coordinates:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lat: ${_latController.text}',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                Text(
                                  'Long: ${_longController.text}',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: widget.saveAddress
                      ? BlocBuilder<AddressCubit, AddressState>(
                    builder: (context, state) {
                      final isLoading = state is AddressLoading;
                      return AppCustomButton(
                        onPressed: isLoading ? () {} : _submit,
                        text: widget.address != null
                            ? AppLocalizations.of(context)!.updateAddress
                            : AppLocalizations.of(context)!.addAddress,
                        isLoading: isLoading,
                      );
                    },
                  )
                      : AppCustomButton(
                    onPressed: _submit,
                    text: 'Use This Address',
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