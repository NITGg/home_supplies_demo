import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';

import '../../../../../../core/widgets/custom_button.dart';
import '../../../../../../core/widgets/loading_screen.dart';
import '../../../../../addresses/data/models/address_model.dart';
import '../../../../../addresses/manager/address_cubit.dart';
import '../../../../../addresses/manager/address_states.dart';
import '../../../../../addresses/presentation/address_form_sheet.dart';

class AddressSelectionSheet extends StatefulWidget {
  final String title;
  final bool isPickup;

  const AddressSelectionSheet({
    super.key,
    required this.title,
    required this.isPickup,
  });

  @override
  State<AddressSelectionSheet> createState() => _AddressSelectionSheetState();
}

class _AddressSelectionSheetState extends State<AddressSelectionSheet> {
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
        providers: [BlocProvider.value(value: addressCubit)],
        child: AddressFormBottomSheet(
          saveAddress: saveAddress,
          isPickup: widget.isPickup,
        ),
      ),
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  text: l10n.addAddress,
                  isSecondary: true,
                ),
                const SizedBox(height: 8),
                AppCustomButton(
                  onPressed: () => _showAddressForm(saveAddress: false),
                  text: l10n.oneTimeAddress,
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
                  return const Center(
                    child: LoadingScreen(isOne: true, asWidget: true),
                  );
                }
                if (state is AddressError) {
                  return Center(child: Text(state.message));
                }
                if (state is AddressesLoaded) {
                  if (state.addresses.isEmpty) {
                    return const Center(child: Text(''));
                  }

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
                            widget.isPickup ? Icons.store : Icons.location_on,
                            color: widget.isPickup ? Colors.green : Colors.blue,
                          ),
                          title: Text(
                            address.displayAddress,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                          ),
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
