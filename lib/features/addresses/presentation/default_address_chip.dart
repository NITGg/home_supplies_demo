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
/// Auto-refreshes via [RouteAware] every time its parent route becomes the
/// top-most route again (e.g. after dismissing [DefaultAddressPickerSheet],
/// returning from an address-edit screen, or any other navigation pop).
class DefaultAddressChip extends StatefulWidget {
  const DefaultAddressChip({super.key});

  @override
  State<DefaultAddressChip> createState() => _DefaultAddressChipState();
}

class _DefaultAddressChipState extends State<DefaultAddressChip>
    with RouteAware {
  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe/re-subscribe whenever the widget's route context changes.
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

  /// Called when this route is pushed onto the navigator (initial appearance).
  @override
  void didPush() => _reload();

  /// Called when a route above this one is popped — i.e. this chip is visible
  /// again after any navigation (sheet closed, back button pressed, etc.).
  @override
  void didPopNext() => _reload();

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _loadIfNeeded() {
    if (context.read<AddressCubit>().state is AddressInitial) _reload();
  }

  void _reload() {
    if (mounted) context.read<AddressCubit>().loadAddresses();
  }

  void _showAddressSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<AddressCubit>(),
        child: const DefaultAddressPickerSheet(),
      ),
    );
    // No manual reload needed here — didPopNext fires when the sheet closes.
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddressCubit, AddressState>(
      builder: (context, state) {
        if (state is AddressLoading || state is AddressInitial) {
          return const _SkeletonChip();
        }

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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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