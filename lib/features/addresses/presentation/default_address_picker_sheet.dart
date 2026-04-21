import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/style/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/address_model.dart';
import '../manager/address_cubit.dart';
import '../manager/address_states.dart';
import 'address_form_sheet.dart';

/// A bottom sheet shown on app launch that lets the user:
///   • Pick an existing address and mark it as default (via update).
///   • Add a brand-new address (delegates to [AddressFormBottomSheet]).
///
/// Dismiss by tapping the close button or dragging down — no forced action.
class DefaultAddressPickerSheet extends StatefulWidget {
  const DefaultAddressPickerSheet({super.key});

  @override
  State<DefaultAddressPickerSheet> createState() =>
      _DefaultAddressPickerSheetState();
}

class _DefaultAddressPickerSheetState
    extends State<DefaultAddressPickerSheet> {
  // The address the user has tapped (highlighted but not yet confirmed).
  int? _pendingDefaultId;

  // Whether we are mid-save (updating the address to isDefault = true).
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    context.read<AddressCubit>().loadAddresses();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Opens [AddressFormBottomSheet] in add-mode and reloads the list after.
  Future<void> _openAddSheet() async {
    final addressCubit = context.read<AddressCubit>();

    await showModalBottomSheet<Address>(
      isDismissible: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: addressCubit,
        child: const AddressFormBottomSheet(),
      ),
    );

    // AddressCubit.createAddress() already calls loadAddresses() internally,
    // but we call it again in case the user only dismissed the form sheet.
    if (mounted) addressCubit.loadAddresses();
  }

  /// Saves the pending selection as default and closes the sheet.
  /// If the selected address is already the default, just closes — no API call.
  Future<void> _confirmDefault(List<Address> addresses) async {
    if (_pendingDefaultId == null) return;

    final address = addresses.firstWhere((a) => a.id == _pendingDefaultId);

    // Already the default — nothing to update, just dismiss.
    if (address.isDefault) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);

    // Re-use the existing update flow; the cubit emits AddressOperationSuccess
    // then reloads the list.
    await context
        .read<AddressCubit>()
        .updateAddress(address.id!, address.copyWith(isDefault: true));

    if (mounted) Navigator.pop(context);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      // Match the height profile of AddressSelectionBottomSheet.
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
          // ── Drag handle ──────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.kSecondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.home_outlined,
                    color: AppColors.kSecondaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.deliveryLocation,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        l10n.setAsDefault,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
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

          // ── Add-address shortcut ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppCustomButton(
              onPressed: _openAddSheet,
              text: l10n.addAddress,
              isSecondary: true,
            ),
          ),

          // ── Address list ─────────────────────────────────────────────────
          Expanded(
            child: BlocConsumer<AddressCubit, AddressState>(
              listener: (context, state) {
                // If the cubit finished an operation (error or loaded),
                // clear the saving spinner.
                if (state is AddressError || state is AddressesLoaded) {
                  if (_saving && mounted) setState(() => _saving = false);
                }
              },
              builder: (context, state) {
                // ── Loading ──────────────────────────────────────────────
                if (state is AddressLoading && !_saving) {
                  return const Center(
                    child: LoadingScreen(isOne: true, asWidget: true),
                  );
                }

                // ── Error ────────────────────────────────────────────────
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
                        const SizedBox(height: 12),
                        Text(state.message),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () =>
                              context.read<AddressCubit>().loadAddresses(),
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.retry),
                        ),
                      ],
                    ),
                  );
                }

                // ── Loaded ───────────────────────────────────────────────
                if (state is AddressesLoaded) {
                  final addresses = state.addresses;

                  if (addresses.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_location_alt_outlined,
                              size: 56,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.addAddress,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Pre-select the current default so the UI is coherent.
                  _pendingDefaultId ??=
                      addresses.firstWhere(
                            (a) => a.isDefault,
                        orElse: () => addresses.first,
                      ).id;

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: addresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      final isSelected = address.id == _pendingDefaultId;
                      final isCurrentDefault = address.isDefault;

                      return _AddressTile(
                        address: address,
                        isSelected: isSelected,
                        isCurrentDefault: isCurrentDefault,
                        onTap: () =>
                            setState(() => _pendingDefaultId = address.id),
                      );
                    },
                  );
                }

                return const SizedBox();
              },
            ),
          ),

          // ── Confirm button ───────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: BlocBuilder<AddressCubit, AddressState>(
                builder: (context, state) {
                  final addresses =
                  state is AddressesLoaded ? state.addresses : <Address>[];
                  final isLoading =
                      _saving || state is AddressLoading;

                  // Hide the confirm button when there is nothing to confirm.
                  if (addresses.isEmpty) return const SizedBox();

                  return AppCustomButton(
                    onPressed:
                    isLoading ? () {} : () => _confirmDefault(addresses),
                    text: l10n.confirm,
                    isLoading: isLoading,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Address tile ─────────────────────────────────────────────────────────────

class _AddressTile extends StatelessWidget {
  final Address address;
  final bool isSelected;
  final bool isCurrentDefault;
  final VoidCallback onTap;

  const _AddressTile({
    required this.address,
    required this.isSelected,
    required this.isCurrentDefault,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Card(
      color: Colors.white,
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? primaryColor : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Radio circle ──────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey.shade400,
                    width: 2,
                  ),
                  color:
                  isSelected ? primaryColor : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),

              // ── Text ──────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (address.name != null &&
                            address.name!.isNotEmpty) ...[
                          Text(
                            address.name!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (isCurrentDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.default_,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.detailedAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Location pin icon ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  isCurrentDefault ? Icons.home : Icons.location_on_outlined,
                  size: 20,
                  color: isCurrentDefault
                      ? Colors.green.shade600
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}