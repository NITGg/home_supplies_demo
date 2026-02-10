import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../manager/address_cubit.dart';
import '../manager/address_states.dart';
import 'address_sheet.dart';

class AddressFieldWidget extends StatefulWidget {
  final Function(int?) onAddressSelected;

  const AddressFieldWidget({
    super.key,
    required this.onAddressSelected,
  });

  @override
  State<AddressFieldWidget> createState() => _AddressFieldWidgetState();
}

class _AddressFieldWidgetState extends State<AddressFieldWidget> {
  String? _address;
  int? _addressId;
  AddressCubit? _addressCubit;
  bool _isLoadingDefault = true;

  @override
  void initState() {
    super.initState();
    // _loadDefaultAddress();
  }

  @override
  void dispose() {
    _addressCubit?.close();
    super.dispose();
  }

  // Future<void> _loadDefaultAddress() async {
  //   _addressCubit = AddressCubit();
  //
  //   // Set up the listener BEFORE calling loadAddresses
  //   final subscription = _addressCubit!.stream.listen((state) {
  //     if (!mounted) return;
  //
  //     if (state is AddressesLoaded) {
  //       if (state.addresses.isEmpty) {
  //         setState(() => _isLoadingDefault = false);
  //         return;
  //       }
  //
  //       final defaultAddress = state.addresses.firstWhere(
  //             (addr) => addr.isDefault ?? false,
  //         orElse: () => state.addresses.first,
  //       );
  //
  //       setState(() {
  //         _addressId = defaultAddress.id;
  //         _address = defaultAddress.fullAddress;
  //         _isLoadingDefault = false;
  //       });
  //       widget.onAddressSelected(defaultAddress.id);
  //     } else if (state is AddressError) {
  //       setState(() => _isLoadingDefault = false);
  //     }
  //   });
  //
  //   // Now load the addresses
  //   try {
  //     await _addressCubit!.loadAddresses();
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() => _isLoadingDefault = false);
  //     }
  //   }
  // }

  Future<void> _selectAddress() async {
    // Create a new cubit instance for the sheet
    final addressCubit = AddressCubit();

    final result = await showModalBottomSheet<List<dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: addressCubit,
        child: const AddressSelectionBottomSheet(),
      ),
    );

    // Clean up the cubit after the sheet is closed
    addressCubit.close();

    if (result != null && mounted) {
      setState(() {
        _addressId = result[0];
        _address = result[1];
      });
      widget.onAddressSelected(result[0]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isLoadingDefault ? null : _selectAddress,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: _address == null ? Colors.red.shade200 : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (_isLoadingDefault)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.location_on_outlined,
                    color: _address == null ? Colors.red : Colors.grey[600],
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    _isLoadingDefault
                        ? '...'
                        : _address ?? AppLocalizations.of(context)!.address,
                    style: TextStyle(
                      fontSize: 14,
                      color: _address == null ? Colors.red : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_isLoadingDefault)
                  Icon(
                    Icons.arrow_drop_down,
                    color: Colors.grey[600],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}