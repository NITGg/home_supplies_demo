import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/style/app_colors.dart';
import '../../ads/presentation/widgets/popups.dart';
import '../../addresses/manager/address_cubit.dart';
import '../../addresses/manager/address_states.dart';
import '../../addresses/presentation/default_address_chip.dart';
import '../../cart/presentation/widgets/cart_button.dart';
import '../../home/layout/manager/guest_cubit.dart';
import '../../search/presentation/search_dialog.dart';
import '../data/models/category_models.dart';
import 'categories_grid_widget.dart';

class CategoriesScreen extends StatefulWidget {
  final void Function(bool isEmpty)? onEmptyChanged;

  const CategoriesScreen({super.key, this.onEmptyChanged});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final GlobalKey<CategoriesGridWidgetState> _categoriesKey = GlobalKey();
  bool _categoriesEmpty = false;

  /// ID of the default address that was active the last time categories loaded.
  /// Used to detect a genuine address change vs. a routine reload.
  int? _lastDefaultAddressId;

  /// Coordinates of the default address that was active the last time
  /// categories loaded. Used to detect when the same default address was
  /// edited to a new location (its ID doesn't change in that case).
  String? _lastDefaultAddressLocation;

  /// True once we've received at least one non-empty address list.
  /// Allows us to detect the "all deleted → new address added" case and
  /// refresh, while still suppressing a refresh on the very first load.
  bool _hadAddress = false;

  void _navigateToCategory(CategoryModel category) {
    context.push('/categories/${category.id}', extra: category);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AddressCubit, AddressState>(
      listener: (context, state) {
        if (state is! AddressesLoaded) return;
        final defaultAddress = state.addresses
            .where((a) => a.isDefault)
            .firstOrNull ?? state.addresses.firstOrNull;
        final newDefault = defaultAddress?.id;
        final newLocation = defaultAddress == null
            ? null
            : '${defaultAddress.addressLat},${defaultAddress.addressLong}';

        final idChanged = newDefault != _lastDefaultAddressId;
        final locationChanged = newDefault != null &&
            newDefault == _lastDefaultAddressId &&
            newLocation != _lastDefaultAddressLocation;

        if ((idChanged &&
                (_hadAddress ||
                    (_lastDefaultAddressId == null && newDefault != null))) ||
            locationChanged) {
          // Default address changed (including null → new after deletion,
          // or a first address being created for a brand-new user), or the
          // default address was edited to a new location — refresh so
          // products reflect the new delivery location.
          _categoriesKey.currentState?.refresh();
        }
        _lastDefaultAddressId = newDefault;
        _lastDefaultAddressLocation = newLocation;
        if (newDefault != null) _hadAddress = true;
      },
      child: RefreshIndicator(
      onRefresh: () => _categoriesKey.currentState?.refresh() ?? Future.value(),
      color: AppColors.kPrimaryColor,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: PopupAdsHandler()),

          // Pinned sticky header — only the search/address/cart row.
          // Hidden entirely when categories are empty (fallback view).
          if (!_categoriesEmpty)
            SliverAppBar(
              actions: const [SizedBox.shrink()],
              pinned: true,
              toolbarHeight: 60,
              automaticallyImplyLeading: false,
              scrolledUnderElevation: 2,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              titleSpacing: 0,
              title: BlocBuilder<GuestModeCubit, bool>(
                builder: (context, guest) => Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.kPrimaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!guest) ...[
                        const DefaultAddressChip(),
                        const SizedBox(width: 8),
                      ],
                      const Spacer(),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey.shade200,
                        child: IconButton(
                          icon: Icon(
                            Icons.search_rounded,
                            color: Colors.grey.shade700,
                          ),
                          onPressed: () => showSearchDialog(context),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 4),
                      CartButton(),
                    ],
                  ),
                ),
              ),
            ),

          // Everything else scrolls: ads + product sections + categories grid
          SliverToBoxAdapter(
            child: CategoriesGridWidget(
              key: _categoriesKey,
              onCategoryTap: _navigateToCategory,
              showHeader: false,
              onEmptyChanged: (isEmpty) {
                setState(() => _categoriesEmpty = isEmpty);
                widget.onEmptyChanged?.call(isEmpty);
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 300)),
        ],
      ),
      ),
    );
  }
}
