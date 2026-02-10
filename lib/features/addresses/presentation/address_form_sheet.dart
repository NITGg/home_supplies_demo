import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/text_form.dart';
import '../../../l10n/app_localizations.dart';

import '../data/models/address_model.dart';
import '../manager/address_cubit.dart';
import '../manager/address_states.dart';
import '../manager/governorate_cubit.dart';
import '../manager/governorate_states.dart';
import '../manager/location_cubit.dart';

class AddressFormBottomSheet extends StatefulWidget {
  final Address? address;

  /// When true  → save to server, show name + default fields.
  /// When false → return address object only, hide name + default fields.
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
  late TextEditingController _nameController;
  late TextEditingController _detailedAddressController;
  late TextEditingController _latController;
  late TextEditingController _longController;

  int? _selectedAreaId;
  bool _isDefault = false;
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.address?.name);
    _detailedAddressController =
        TextEditingController(text: widget.address?.detailedAddress);
    _latController =
        TextEditingController(text: widget.address?.addressLat);
    _longController =
        TextEditingController(text: widget.address?.addressLong);
    _selectedAreaId = widget.address?.areaId;
    _isDefault = widget.address?.isDefault ?? false;
    _hasLocation = _latController.text.isNotEmpty &&
        _longController.text.isNotEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _detailedAddressController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    context.read<LocationCubit>().getCurrentLocation();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Area is validated by the DropdownButtonFormField validator,
      // but double-check here to show a SnackBar fallback.
      if (_selectedAreaId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.pleaseSelectArea,
            ),
          ),
        );
        return;
      }

      // Lat / Long are always required
      if (_latController.text.trim().isEmpty ||
          _longController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.pleaseSelectLocation,
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final address = Address(
        id: widget.address?.id,
        areaId: _selectedAreaId!,
        // Name and isDefault are only relevant when saving
        name: widget.saveAddress
            ? (_nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim())
            : null,
        addressLat: _latController.text.trim(),
        addressLong: _longController.text.trim(),
        detailedAddress: _detailedAddressController.text.trim(),
        isDefault: widget.saveAddress ? _isDefault : false,
      );

      if (widget.saveAddress) {
        if (widget.address != null) {
          context.read<AddressCubit>().updateAddress(
            widget.address!.id!,
            address,
          );
        } else {
          context.read<AddressCubit>().createAddress(address);
        }
      } else {
        Navigator.pop(context, address);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = l10n.localeName == 'ar';

    return MultiBlocListener(
      listeners: [
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
                      Expanded(
                        child: Text(
                          widget.address != null
                              ? l10n.edit
                              : l10n.detailedAddress,
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
                        // ── Address Name (only when saving) ─────────────────
                        if (widget.saveAddress) ...[
                          AppTextFormField(
                            controller: _nameController,
                            label: l10n.addressNameOptional,
                            hintText: l10n.addressNameHint,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Area Selection ───────────────────────────────────
                        BlocProvider(
                          create: (_) =>
                          GovernorateCubit()..loadGovernorates(),
                          child: BlocBuilder<GovernorateCubit,
                              GovernorateState>(
                            builder: (context, state) {
                              if (state is GovernorateLoading) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (state is GovernorateError) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius:
                                    BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: Colors.red.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          state.message,
                                          style: TextStyle(
                                            color: Colors.red.shade900,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => context
                                            .read<GovernorateCubit>()
                                            .loadGovernorates(),
                                        child: Text(l10n.retry),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (state is GovernoratesLoaded) {
                                final areas = state.response.allAreas;

                                if (areas.isEmpty) {
                                  return Text(
                                    l10n.noAreasAvailable,
                                    style: const TextStyle(
                                        color: Colors.grey),
                                  );
                                }

                                return DropdownButtonFormField<int>(
                                  value: _selectedAreaId,
                                  decoration: InputDecoration(
                                    labelText: l10n.selectArea,
                                    border: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(
                                        Icons.location_city),
                                  ),
                                  items: areas.map((area) {
                                    final governorate = state.response
                                        .getGovernorateForArea(area.id);
                                    return DropdownMenuItem(
                                      value: area.id,
                                      child: Text(
                                        '${governorate?.getLocalizedName(isArabic) ?? ''} - ${area.getLocalizedName(isArabic)}',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(
                                            () => _selectedAreaId = value);
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return l10n.pleaseSelectArea;
                                    }
                                    return null;
                                  },
                                );
                              }

                              return const SizedBox();
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Detailed Address ─────────────────────────────────
                        AppTextFormField(
                          controller: _detailedAddressController,
                          label: l10n.detailedAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.required;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Set as Default (only when saving) ────────────────
                        if (widget.saveAddress) ...[
                          CheckboxListTile(
                            activeColor: Colors.orangeAccent,
                            title: Text(l10n.setAsDefault),
                            value: _isDefault,
                            onChanged: (value) {
                              setState(
                                      () => _isDefault = value ?? false);
                            },
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                            ListTileControlAffinity.leading,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Location error ───────────────────────────────────
                        BlocBuilder<LocationCubit, LocationState>(
                          builder: (context, locationState) {
                            if (locationState is LocationError) {
                              return AnimatedContainer(
                                duration:
                                const Duration(milliseconds: 300),
                                margin:
                                const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius:
                                  BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: Colors.red.shade700,
                                        size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            locationState.message,
                                            style: TextStyle(
                                              color:
                                              Colors.red.shade900,
                                              fontSize: 14,
                                              fontWeight:
                                              FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          GestureDetector(
                                            onTap: () => context
                                                .read<LocationCubit>()
                                                .openLocationSettings(),
                                            child: Row(
                                              mainAxisSize:
                                              MainAxisSize.min,
                                              children: [
                                                Icon(Icons.settings,
                                                    size: 16,
                                                    color: Colors
                                                        .red.shade700),
                                                const SizedBox(
                                                    width: 4),
                                                Text(
                                                  l10n.openSettings,
                                                  style: TextStyle(
                                                    color: Colors
                                                        .red.shade700,
                                                    fontSize: 14,
                                                    fontWeight:
                                                    FontWeight.bold,
                                                    decoration:
                                                    TextDecoration
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

                        // ── Location status + button ──────────────────────────
                        Column(
                          children: [
                            // Success indicator
                            if (_hasLocation)
                              TweenAnimationBuilder<double>(
                                duration:
                                const Duration(milliseconds: 600),
                                tween: Tween(begin: 0.0, end: 1.0),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          8, 0, 8, 10),
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
                                          Icon(Icons.location_on,
                                              color:
                                              Colors.green.shade700,
                                              size: 24),
                                          const SizedBox(width: 8),
                                          Icon(Icons.check_circle,
                                              color:
                                              Colors.green.shade700,
                                              size: 24),
                                          const SizedBox(width: 12),
                                          Text(
                                            l10n.locationObtained,
                                            style: TextStyle(
                                              color:
                                              Colors.green.shade700,
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

                            // Location required warning (shown only if
                            // user tries to submit without location)
                            if (!_hasLocation)
                              Padding(
                                padding:
                                const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 14,
                                        color: Colors.orange.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.locationRequired,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Get location button
                            BlocBuilder<LocationCubit, LocationState>(
                              builder: (context, locationState) {
                                final isLoading =
                                locationState is LocationLoading;
                                return AppCustomButton(
                                  isSecondary: true,
                                  onPressed: _getCurrentLocation,
                                  text: l10n.useCurrentLocation,
                                  isLoading: isLoading,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Submit Button ────────────────────────────────────────────
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: widget.saveAddress
                        ? BlocBuilder<AddressCubit, AddressState>(
                      builder: (context, state) {
                        final isLoading =
                        state is AddressLoading;
                        return AppCustomButton(
                          onPressed: isLoading ? () {} : _submit,
                          text: widget.address != null
                              ? l10n.updateAddress
                              : l10n.addAddress,
                          isLoading: isLoading,
                        );
                      },
                    )
                        : AppCustomButton(
                      onPressed: _submit,
                      text: l10n.useThisAddress,
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