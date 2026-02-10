import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../manager/address_cubit.dart';
import 'address_sheet.dart';

/// Compact address field used inside forms (e.g. checkout).
/// Tapping it opens [AddressSelectionBottomSheet] in selection mode and
/// reports the chosen address id back via [onAddressSelected].
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

  Future<void> _selectAddress() async {
    final addressCubit = AddressCubit();

    final result = await showModalBottomSheet<List<dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: addressCubit,
        child: const AddressSelectionBottomSheet(
          managementMode: false,
        ),
      ),
    );

    addressCubit.close();

    if (result != null && mounted) {
      setState(() {
        _addressId = result[0] as int?;
        _address = result[1] as String?;
      });
      widget.onAddressSelected(_addressId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _selectAddress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: _address == null
                ? Colors.red.shade200
                : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: _address == null ? Colors.red : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                textAlign: TextAlign.start,
                textDirection: TextDirection.ltr,
                _address ?? AppLocalizations.of(context)!.address,
                style: TextStyle(
                  fontSize: 14,
                  color: _address == null ? Colors.red : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}