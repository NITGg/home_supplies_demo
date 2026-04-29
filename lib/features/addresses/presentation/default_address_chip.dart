import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';
import '../data/models/address_model.dart';
import '../manager/address_cubit.dart';
import '../manager/address_states.dart';
import 'default_address_picker_sheet.dart';

/// A [RouteObserver] that must be registered in [MaterialApp.navigatorObservers].
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [addressChipRouteObserver],
/// )
/// ```
final RouteObserver<ModalRoute<void>> addressChipRouteObserver =
RouteObserver<ModalRoute<void>>();

/// A compact chip that shows the default address name.
///
/// • When the user taps it the [DefaultAddressPickerSheet] opens.
/// • If there are no addresses the sheet auto-opens the add-address flow,
///   so the user is guided to create one without any extra taps.
/// • Auto-refreshes via [RouteAware] every time its parent route becomes the
///   top-most route again (e.g. after dismissing a sheet or navigating back).
class DefaultAddressChip extends StatefulWidget {
  const DefaultAddressChip({super.key});

  @override
  State<DefaultAddressChip> createState() => _DefaultAddressChipState();
}

class _DefaultAddressChipState extends State<DefaultAddressChip>
    with RouteAware {
  /// Prevents the sheet from auto-popping more than once per app session.
  /// Reset when the user navigates back to this route so a fresh reload
  /// can trigger it again only if addresses are still missing.
  bool _sheetAutoShown = false;

  /// True while [DefaultAddressPickerSheet] is currently mounted.
  /// Prevents a second sheet being pushed on top when addresses are deleted
  /// from within the already-open sheet.
  bool _sheetIsOpen = false;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      addressChipRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    addressChipRouteObserver.unsubscribe(this);
    super.dispose();
  }

  // ── RouteAware callbacks ────────────────────────────────────────────────────

  @override
  void didPush() => _reload();

  @override
  void didPopNext() {
    _sheetAutoShown = false; // allow re-trigger if addresses are still missing
    _reload();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _loadIfNeeded() {
    if (context.read<AddressCubit>().state is AddressInitial) _reload();
  }

  void _reload() {
    if (mounted) context.read<AddressCubit>().loadAddresses();
  }

  void _showAddressSheet(BuildContext context) {
    if (_sheetIsOpen) return;
    _sheetIsOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<AddressCubit>(),
        child: const DefaultAddressPickerSheet(),
      ),
    ).whenComplete(() {
      _sheetIsOpen = false;
    });
    // No manual reload needed here — didPopNext fires when the sheet closes.
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddressCubit, AddressState>(
      listener: (context, state) {
        if (state is AddressesLoaded &&
            state.addresses.isEmpty &&
            !_sheetAutoShown &&
            !_sheetIsOpen) {
          _sheetAutoShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showAddressSheet(context);
          });
        }
        // Once addresses exist, reset so a future empty state re-triggers.
        if (state is AddressesLoaded && state.addresses.isNotEmpty) {
          _sheetAutoShown = false;
        }
      },
      builder: (context, state) {
        if (state is AddressLoading || state is AddressInitial) {
          return const _SkeletonChip();
        }

        // ── No addresses: show a prompt chip that opens the add flow ────────
        if (state is AddressesLoaded && state.addresses.isEmpty) {
          return GestureDetector(
            onTap: () => _showAddressSheet(context),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade300, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_location_alt_outlined,
                    size: 13,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!.addAddress,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }

        // ── Has addresses: show the default/first address ────────────────────
        if (state is! AddressesLoaded || state.addresses.isEmpty) {
          return const SizedBox.shrink();
        }

        final Address? defaultAddress =
            state.addresses.where((a) => a.isDefault).firstOrNull ??
                state.addresses.firstOrNull;

        if (defaultAddress == null) return const SizedBox.shrink();

        final label = defaultAddress.name?.isNotEmpty == true
            ? defaultAddress.name!
            : defaultAddress.detailedAddress;

        return GestureDetector(
          onTap: () => _showAddressSheet(context),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 13,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${AppLocalizations.of(context)!.delivery} ${AppLocalizations.of(context)!.to} $label',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton chip (shown while loading)
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonChip extends StatelessWidget {
  const _SkeletonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}