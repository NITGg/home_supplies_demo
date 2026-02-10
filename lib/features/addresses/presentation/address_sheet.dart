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

  /// When true: sheet is purely for management (no selection / continue button).
  /// When false (default): sheet is for picking an address and returning it.
  final bool managementMode;

  const AddressSelectionBottomSheet({
    super.key,
    this.selectedAddress,
    this.managementMode = false,
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

  Future<void> _showAddSheet() async {
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
        child: const AddressFormBottomSheet(),
      ),
    );

    if (result != null && mounted) {
      setState(() => _selectedAddress = result);
    }
  }

  Future<void> _showEditSheet(Address address) async {
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

    if (result != null && mounted) {
      setState(() => _selectedAddress = result);
    }
  }

  void _confirmDelete(Address address) {
    final addressCubit = context.read<AddressCubit>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '${AppLocalizations.of(context)!.delete} ${AppLocalizations.of(context)!.address}',
        ),
        content: Text(
          '${AppLocalizations.of(context)!.areYouSureDelete}\n"${address.detailedAddress.split(' ').first}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
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

  void _selectAndReturn() {
    if (_selectedAddress != null) {
      Navigator.pop(context, [
        _selectedAddress!.id,
        _selectedAddress!.detailedAddress,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.65,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppCustomButton(
              onPressed: _showAddSheet,
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
                            AppLocalizations.of(context)!.addAddress,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: state.addresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                          onTap: widget.managementMode
                              ? null
                              : () => setState(
                                () => _selectedAddress = address,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Selection indicator or icon
                                if (!widget.managementMode)
                                  AnimatedContainer(
                                    duration:
                                    const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(
                                        top: 2, right: 10),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check,
                                        size: 12, color: Colors.white)
                                        : null,
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 2, right: 10),
                                    child: Icon(
                                      Icons.location_on_outlined,
                                      size: 20,
                                      color:
                                      Theme.of(context).primaryColor,
                                    ),
                                  ),

                                // Address details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (address.name != null &&
                                              address.name!.isNotEmpty)
                                            Text(
                                              address.name!,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          if (address.isDefault) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.default_,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                  Colors.green.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        address.detailedAddress,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Always show edit/delete popup
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditSheet(address);
                                    } else if (value == 'delete') {
                                      _confirmDelete(address);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            AppLocalizations.of(context)!
                                                .edit,
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.delete,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            AppLocalizations.of(context)!
                                                .delete,
                                            style: const TextStyle(
                                                color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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

          // Continue button (only in selection mode)
          if (!widget.managementMode && _selectedAddress != null)
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