import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/address_model.dart';
import '../manager/address_cubit.dart';
import '../manager/address_states.dart';
import '../manager/location_cubit.dart';
import 'address_form_sheet.dart';

class AddressSelectionBottomSheet extends StatefulWidget {
  final Address? selectedAddress;
  final bool? noSelection;

  const AddressSelectionBottomSheet({
    super.key,
    this.selectedAddress,
    this.noSelection,
  });

  @override
  State<AddressSelectionBottomSheet> createState() =>
      _AddressSelectionBottomSheetState();
}

class _AddressSelectionBottomSheetState
    extends State<AddressSelectionBottomSheet> {
  Address? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.selectedAddress;
    context.read<AddressCubit>().loadAddresses();
  }

  void _showAddAddressSheet() async {
    final addressCubit = context.read<AddressCubit>();

    final result = await showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: addressCubit),
          BlocProvider(create: (_) => LocationCubit()),
          // Create new LocationCubit
        ],
        child: const AddressFormBottomSheet(),
      ),
    );

    if (result != null) {
      setState(() => _selectedAddress = result);
    }
  }

  void _showEditAddressSheet(Address address) async {
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
        child: AddressFormBottomSheet(address: address),
      ),
    );

    if (result != null) {
      setState(() => _selectedAddress = result);
    }
  }

  void _confirmDelete(BuildContext sheetContext, Address address) {
    // Store the cubit reference before showing the dialog
    final addressCubit = sheetContext.read<AddressCubit>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '${AppLocalizations.of(context)!.delete} ${AppLocalizations.of(context)!.address}',
        ),
        content: Text(
          '${AppLocalizations.of(context)!.areYouSureDelete} \n "${address.detailedAddress.split(' ').first}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Use the stored cubit reference instead of trying to read from dialog context
              addressCubit.deleteAddress(address.id!);
              if (_selectedAddress?.id == address.id) {
                setState(() => _selectedAddress = null);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  // void _setAsDefault(Address address) {
  //   context.read<AddressCubit>().setDefaultAddress(address.id!, address);
  // }

  void _selectAndReturn() {
    if (_selectedAddress != null) {
      Navigator.pop(context, [
        _selectedAddress!.id,
        _selectedAddress!.detailedAddress,
      ]);
    }
  }

  // Auto-select default address when addresses are loaded
  // void _autoSelectDefaultAddress(List<Address> addresses) {
  //   if (_selectedAddress == null && addresses.isNotEmpty) {
  //     final defaultAddress = addresses.firstWhere(
  //       (addr) => addr.isDefault ?? false,
  //       orElse: () => addresses.first,
  //     );
  //     // Set directly without setState to avoid calling setState during build
  //     _selectedAddress = defaultAddress;
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.6,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
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
                    AppLocalizations.of(context)!.address,
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
          // Add Address Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppCustomButton(
              onPressed: _showAddAddressSheet,
              text: AppLocalizations.of(context)!.addAddress,
              isSecondary: true,
            ),
          ),
          // Address List
          Expanded(
            child: BlocBuilder<AddressCubit, AddressState>(
              builder: (context, state) {
                if (state is AddressLoading) {
                  return const Center(
                    child: LoadingScreen(isOne: true, asWidget: true),
                  );
                }

                if (state is AddressError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(state.message),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () =>
                              context.read<AddressCubit>().loadAddresses(),
                          child: Text(AppLocalizations.of(context)!.retry),
                        ),
                      ],
                    ),
                  );
                }

                if (state is AddressesLoaded) {
                  // Auto-select default address
                  // _autoSelectDefaultAddress(state.addresses);

                  if (state.addresses.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_location_alt_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.addAddress,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.addresses.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final address = state.addresses[index];
                      final isSelected = _selectedAddress?.id == address.id;

                      return Card(
                        color: Colors.white,
                        elevation: isSelected ? 4 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedAddress = address),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            address.detailedAddress.split(' ').first,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          // if (address.isDefault ?? false) ...[
                                          //   const SizedBox(width: 8),
                                          //   Container(
                                          //     padding:
                                          //         const EdgeInsets.symmetric(
                                          //           horizontal: 8,
                                          //           vertical: 2,
                                          //         ),
                                          //     decoration: BoxDecoration(
                                          //       color: Colors.green,
                                          //       borderRadius:
                                          //           BorderRadius.circular(4),
                                          //     ),
                                          //     child: Text(
                                          //       AppLocalizations.of(
                                          //         context,
                                          //       )!.default_,
                                          //       style: const TextStyle(
                                          //         color: Colors.white,
                                          //         fontSize: 10,
                                          //       ),
                                          //     ),
                                          //   ),
                                          // ],
                                        ],
                                      ),
                                    ),
                                    if (widget.noSelection ?? false)
                                      PopupMenuButton(
                                        itemBuilder: (popupContext) => [
                                          PopupMenuItem(
                                            onTap: () =>
                                                _showEditAddressSheet(address),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.edit,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  )!.edit,
                                                ),
                                              ],
                                            ),
                                          ),
                                          // if (!(address.isDefault ?? false))
                                            PopupMenuItem(
                                              // onTap: () =>
                                              //     _setAsDefault(address),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    AppLocalizations.of(
                                                      context,
                                                    )!.default_,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          PopupMenuItem(
                                            onTap: () => _confirmDelete(
                                              context,
                                              address,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.delete,
                                                  size: 20,
                                                  color: Colors.red,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  )!.delete,
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  textDirection: TextDirection.ltr,
                                  address.detailedAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }

                return const SizedBox();
              },
            ),
          ),
          // Select Button
          if (_selectedAddress != null && (widget.noSelection == null))
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppCustomButton(
                      onPressed: _selectAndReturn,
                      text: AppLocalizations.of(context)!.continue_,
                    ),
                    Positioned(
                      left: 0,
                      top: -25,
                      child: Lottie.asset(
                        'assets/animation_json/Location.json',
                        width: 100,
                        height: 100,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
