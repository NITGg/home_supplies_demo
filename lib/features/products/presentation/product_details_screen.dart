import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/formatDate.dart';
import '../../../core/widgets/circel_back_button.dart';
import '../../../core/widgets/highlighter_widget.dart';
import '../../../core/widgets/image_with_fallback.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/data/models/multiple_supplier_exception.dart';
import '../../cart/manager/cart_cubit.dart';
import '../../cart/manager/cart_state.dart';
import '../../cart/presentation/widgets/cart_icon.dart';
import '../../cart/presentation/widgets/multiple_supplier_dialog.dart';
import '../data/models/product_model.dart';
import '../manager/product_detail_cubit.dart';
import '../manager/product_details_states.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel? product;
  final int? productId;

  const ProductDetailScreen({super.key, this.product, this.productId})
      : assert(product != null || productId != null);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductDetailCubit _cubit;

  // Only tracks the selected image thumbnail — cart state is owned by CartCubit.
  int _selectedImageIndex = 0;

  int get _id => widget.product?.id ?? widget.productId!;
  int? get _supplierId => widget.product?.supplierId;

  @override
  void initState() {
    super.initState();
    _cubit = ProductDetailCubit();
    _cubit.load(_id, supplierId: _supplierId);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<ProductDetailCubit, ProductDetailState>(
        builder: (context, state) {
          return switch (state) {
            ProductDetailInitial() ||
            ProductDetailLoading() => _LoadingView(product: widget.product),
            ProductDetailError(:final message) => _ErrorView(
              message: message,
              product: widget.product,
              onRetry: () => _cubit.load(_id, supplierId: _supplierId),
            ),
            ProductDetailLoaded(:final product, :final isSupplierOpen) =>
                _buildLoaded(product, isSupplierOpen: isSupplierOpen),
          };
        },
      ),
    );
  }

  Widget _buildLoaded(ProductModel product, {bool isSupplierOpen = true}) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      bottom: false,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // ── Image gallery app bar ────────────────────────────────────────
            _ImageGalleryAppBar(
              images: product.images,
              selectedIndex: _selectedImageIndex,
              onImageSelected: (i) => setState(() => _selectedImageIndex = i),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NameRow(product: product),
                    const SizedBox(height: 12),
                    _PriceSection(product: product),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StockChip(product: product),
                        if (product.pickupReadyDuration != null)
                          Text(
                            '${l10n.readyIn} : ${formatDuration(product.pickupReadyDuration ?? 0, l10n)}',
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (product.displayDescription.isNotEmpty) ...[
                      _SectionTitle(title: l10n.description),
                      const SizedBox(height: 8),
                      Text(
                        product.displayDescription,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.7,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (product.attributes.isNotEmpty) ...[
                      _SectionTitle(title: l10n.specifications),
                      const SizedBox(height: 8),
                      _AttributesTable(attributes: product.attributes),
                      const SizedBox(height: 20),
                    ],

                    if (product.units.isNotEmpty) ...[
                      _SectionTitle(title: l10n.purchaseUnits),
                      const SizedBox(height: 8),
                      _UnitsRow(units: product.units),
                      const SizedBox(height: 20),
                    ],

                    _MetaInfo(product: product),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── Smart bottom bar — driven entirely by CartCubit state ────────────
        bottomNavigationBar: _AddToCartBar(product: product, isSupplierOpen: isSupplierOpen),
      ),
    );
  }
}

// ── Cart state DTO ────────────────────────────────────────────────────────────
//
// Keeps BlocSelector rebuilds scoped to exactly what the bar cares about.

class _BarCartState {
  final int inCartQty;
  final bool isBusy;

  const _BarCartState({required this.inCartQty, required this.isBusy});

  factory _BarCartState.from(CartState state, int? spId) {
    if (state is! CartLoaded || spId == null) {
      return const _BarCartState(inCartQty: 0, isBusy: false);
    }
    final item = state.data.cartItems.where((i) => i.spId == spId).firstOrNull;
    return _BarCartState(
      inCartQty: item?.quantity ?? 0,
      isBusy: state.isItemBusy(spId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _BarCartState &&
          other.inCartQty == inCartQty &&
          other.isBusy == isBusy;

  @override
  int get hashCode => Object.hash(inCartQty, isBusy);
}

// ── Add-to-cart bottom bar ────────────────────────────────────────────────────

class _AddToCartBar extends StatefulWidget {
  final ProductModel product;
  final bool isSupplierOpen;

  const _AddToCartBar({required this.product, this.isSupplierOpen = true});

  @override
  State<_AddToCartBar> createState() => _AddToCartBarState();
}

class _AddToCartBarState extends State<_AddToCartBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceScale;

  /// True only during the [addItem] call, before the cubit emits a state
  /// that carries a busyItemId. Prevents double-tapping the add button.
  bool _isAdding = false;
  bool _tapLocked = false;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    // Spring: grow → overshoot → settle
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.06,
          end: 0.96,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.96,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 45,
      ),
    ]).animate(_bounceCtrl);
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  // ── Handlers ────────────────────────────────────────────────────────────

  Future<void> _handleAdd(BuildContext ctx) async {
    if (_tapLocked) return; // HARD GUARD (instant)
    _tapLocked = true;

    setState(() => _isAdding = true);

    HapticFeedback.lightImpact();
    _bounceCtrl.forward(from: 0);

    try {
      await ctx.read<CartCubit>().addItem(
        spId: widget.product.spId ?? widget.product.id,
        quantity: 1,
      );
    } on MultipleSupplierException catch (e) {
      if (ctx.mounted) {
        await MultipleSupplierDialog.show(ctx, exception: e);
      }
    } catch (e) {
      if (ctx.mounted) _showError(ctx, extractErrorMessage(e));
    } finally {
      _tapLocked = false; // release immediately
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _handleIncrement(BuildContext ctx) async {
    if (_tapLocked) return;
    _tapLocked = true;

    HapticFeedback.selectionClick();
    _bounceCtrl.forward(from: 0);

    try {
      await ctx.read<CartCubit>().incrementItem(
        widget.product.spId ?? widget.product.id,
      );
    } catch (e) {
      if (ctx.mounted) _showError(ctx, extractErrorMessage(e));
    } finally {
      _tapLocked = false;
    }
  }

  Future<void> _handleDecrement(BuildContext ctx) async {
    if (_tapLocked) return;
    _tapLocked = true;
    HapticFeedback.selectionClick();
    try {
      await ctx.read<CartCubit>().decrementItem(
        widget.product.spId ?? widget.product.id,
      );
    } catch (e) {
      if (ctx.mounted) _showError(ctx, extractErrorMessage(e));
    } finally {
      _tapLocked = false;
    }
  }

  void _showError(BuildContext ctx , [String? message]) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message ?? AppLocalizations.of(ctx)!.cartUpdateFailed),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(ctx).colorScheme.error,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final product = widget.product;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BlocSelector<CartCubit, CartState, _BarCartState>(
        selector: (state) => _BarCartState.from(state, product.spId),
        builder: (ctx, barState) {
          // Merge the local adding flag with the cubit's busy signal so the
          // busy indicator shows from the very first tap until the item
          // appears in the cart state.
          final isBusy = _isAdding || barState.isBusy;

          final Widget content;

          if (product.isOutOfStock) {
            content = _OutOfStockButton(key: const ValueKey('oos'), l10n: l10n);
          } else if (!widget.isSupplierOpen) {
            content = _SupplierClosedButton(
                key: const ValueKey('closed'), l10n: l10n);
          } else if (isBusy) {
            content = _BusyBar(
              key: const ValueKey('busy'),
              color: theme.colorScheme.primary,
            );
          } else if (barState.inCartQty == 0) {
            content = ScaleTransition(
              key: const ValueKey('add'),
              scale: _bounceScale,
              child: _AddButton(
                onTap: () => _handleAdd(ctx),
                theme: theme,
                l10n: l10n,
              ),
            );
          } else {
            content = _QuantityBar(
              key: const ValueKey('qty'),
              quantity: barState.inCartQty,
              max: product.maxAmountForOneOrder,
              bounceScale: _bounceScale,
              theme: theme,
              onIncrement: () => _handleIncrement(ctx),
              onDecrement: () => _handleDecrement(ctx),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              final scaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              );
              final fadeAnim = CurvedAnimation(
                parent: animation,
                curve: Curves.easeIn,
              );
              return ScaleTransition(
                scale: scaleAnim,
                child: FadeTransition(opacity: fadeAnim, child: child),
              );
            },
            child: content,
          );
        },
      ),
    );
  }
}

// ── Out of stock button ───────────────────────────────────────────────────────

class _OutOfStockButton extends StatelessWidget {
  final AppLocalizations l10n;

  const _OutOfStockButton({super.key, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: null,
      icon: const Icon(Icons.remove_shopping_cart_outlined),
      label: Text(
        l10n.outOfStock,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
    );
  }
}

// ── Supplier closed button ────────────────────────────────────────────────────

class _SupplierClosedButton extends StatelessWidget {
  final AppLocalizations l10n;

  const _SupplierClosedButton({super.key, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: null,
      icon: const Icon(Icons.storefront_outlined),
      label: Text(
        l10n.closed,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        disabledBackgroundColor:
        Theme.of(context).colorScheme.errorContainer.withOpacity(0.55),
        disabledForegroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

// ── Busy bar ──────────────────────────────────────────────────────────────────

class _BusyBar extends StatelessWidget {
  final Color color;

  const _BusyBar({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
        ),
      ),
    );
  }
}

// ── Add button ────────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _AddButton({
    required this.onTap,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_shopping_cart_rounded),
      label: Text(
        l10n.addToCart,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ── Full-width quantity pill ──────────────────────────────────────────────────

class _QuantityBar extends StatelessWidget {
  final int quantity;
  final int? max;
  final Animation<double> bounceScale;
  final ThemeData theme;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QuantityBar({
    super.key,
    required this.quantity,
    this.max,
    required this.bounceScale,
    required this.theme,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;
    final atMax = max != null && quantity >= max!;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _PillButton(
            icon: Icons.remove_rounded,
            onTap: onDecrement,
            enabled: true,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ),
                  ),
                  child: child,
                ),
              ),
              child: Text(
                '$quantity',
                key: ValueKey(quantity),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          ScaleTransition(
            scale: bounceScale,
            child: _PillButton(
              icon: Icons.add_rounded,
              onTap: atMax ? null : onIncrement,
              enabled: !atMax,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const _PillButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 56,
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white38,
          size: 26,
        ),
      ),
    );
  }
}

// ── Image gallery app bar ─────────────────────────────────────────────────────

class _ImageGalleryAppBar extends StatelessWidget {
  final List<String> images;
  final int selectedIndex;
  final void Function(int) onImageSelected;

  const _ImageGalleryAppBar({
    required this.images,
    required this.selectedIndex,
    required this.onImageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      leading: CircleBackButton(),
      actions: [AnimatedCartIcon(onTap: () => context.push('/cart'))],
      flexibleSpace: FlexibleSpaceBar(
        background: images.isEmpty
            ? _placeholder(theme)
            : Stack(
          children: [
            Container(
              color: theme.colorScheme.surfaceContainerLow,
              child: ImageWithIconFallback(
                imageUrl: images[selectedIndex],
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.fitHeight,
                iconSize: 64,
              ),
            ),
            if (images.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: _ThumbnailRow(
                  images: images,
                  selected: selectedIndex,
                  onSelect: onImageSelected,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 80,
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

class _ThumbnailRow extends StatelessWidget {
  final List<String> images;
  final int selected;
  final void Function(int) onSelect;

  const _ThumbnailRow({
    required this.images,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: images.asMap().entries.map((e) {
          final isSelected = e.key == selected;
          return GestureDetector(
            onTap: () => onSelect(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white38,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: ImageWithIconFallback(
                  imageUrl: e.value,
                  fit: BoxFit.cover,
                  width: 48,
                  height: 48,
                  iconSize: 18,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Name row ──────────────────────────────────────────────────────────────────

class _NameRow extends StatelessWidget {
  final ProductModel product;

  const _NameRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.isBestSeller || product.isFeatured)
          Wrap(
            spacing: 6,
            children: [
              if (product.isBestSeller)
                _Chip(label: l10n.bestSeller, color: Colors.amber.shade700),
              if (product.isFeatured)
                _Chip(label: l10n.featured, color: theme.colorScheme.tertiary),
            ],
          ),
        const SizedBox(height: 4),
        Text(
          product.displayName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (product.totalReviews > 0) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              ...List.generate(
                5,
                    (i) => Icon(
                  i < product.rating.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 18,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${product.rating.toStringAsFixed(1)} (${product.totalReviews})',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Price section — uses HighlighterWidget on the discounted price ─────────────

class _PriceSection extends StatelessWidget {
  final ProductModel product;

  const _PriceSection({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (product.hasOffer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Highlighted discounted price ─────────────────────────────
              HighlighterWidget(
                child: Text(
                  '${product.offer!.toStringAsFixed(2)} ${l10n.egp}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // ── Original price struck through ────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${product.price.toStringAsFixed(2)} ${l10n.egp}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          // ── Saving label ─────────────────────────────────────────────────
          if (product.discountPercent != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                HighlighterWidget(
                  child: Text(
                    l10n.percentOff(product.discountPercent!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    return Text(
      '${product.effectivePrice.toStringAsFixed(2)} ${l10n.egp}',
      style: theme.textTheme.headlineMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// ── Stock chip ────────────────────────────────────────────────────────────────

class _StockChip extends StatelessWidget {
  final ProductModel product;

  const _StockChip({required this.product});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (product.isOutOfStock) {
      return _Chip(label: l10n.outOfStock, color: Colors.red);
    }
    if (product.isLowStock) {
      return _Chip(
        label: l10n.lowStockRemaining(
          product.stock.clamp(0, product.maxAmountForOneOrder ?? 10),
        ),
        color: Colors.orange,
      );
    }
    return _Chip(
      label: l10n.inStockCount(
        product.stock.clamp(0, product.maxAmountForOneOrder ?? 10),
      ),
      color: Colors.green,
    );
  }
}

// ── Attributes table ──────────────────────────────────────────────────────────

class _AttributesTable extends StatelessWidget {
  final List<dynamic> attributes;

  const _AttributesTable({required this.attributes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        children: attributes.asMap().entries.map((e) {
          final attr = e.value;
          final isEven = e.key.isEven;
          return TableRow(
            decoration: BoxDecoration(
              color: isEven
                  ? theme.colorScheme.surfaceContainerLowest
                  : theme.colorScheme.surface,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  attr.key,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  attr.displayValue,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Units row ─────────────────────────────────────────────────────────────────

class _UnitsRow extends StatelessWidget {
  final List<dynamic> units;

  const _UnitsRow({required this.units});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: units.map((u) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary, width: 1.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${u.displayName} — ${u.price} ${l10n.egp}',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Meta info ─────────────────────────────────────────────────────────────────

class _MetaInfo extends StatelessWidget {
  final ProductModel product;

  const _MetaInfo({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTextStyle(
      style: theme.textTheme.bodySmall!.copyWith(color: Colors.grey.shade600),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          if (product.weight != null)
            Text('${product.weight} ${AppLocalizations.of(context)!.weight}'),
        ],
      ),
    );
  }
}

// ── Reusable chip ─────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

// ── Loading view ──────────────────────────────────────────────────────────────
// Matches the loaded view structure precisely:
//  • Reuses [_ImageGalleryAppBar] — shows real images when [product] is known,
//    otherwise falls back to the built-in inventory placeholder.
//  • Skeleton rows below mimic the name, price, stock, description, and
//    attributes layout so the transition to loaded is imperceptibly smooth.
//  • A skeleton bottom bar matches the add-to-cart bar shape.

class _LoadingView extends StatefulWidget {
  final ProductModel? product;

  const _LoadingView({this.product});

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.07,
      end: 0.16,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final shimmer = Colors.black.withOpacity(_pulse.value);

        return SafeArea(
          bottom: false,
          child: Scaffold(
            body: CustomScrollView(
              physics: const NeverScrollableScrollPhysics(),
              slivers: [
                // ── Image gallery — real images (or placeholder) ─────────────
                _ImageGalleryAppBar(
                  images: widget.product?.images ?? const [],
                  selectedIndex: 0,
                  onImageSelected: (_) {},
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Name skeleton ──────────────────────────────────────
                        _Skel(color: shimmer, h: 26, w: double.infinity),
                        const SizedBox(height: 7),
                        _Skel(color: shimmer, h: 26, w: 180),
                        const SizedBox(height: 18),

                        // ── Price skeleton ─────────────────────────────────────
                        Row(
                          children: [
                            _Skel(color: shimmer, h: 38, w: 130, r: 10),
                            const SizedBox(width: 10),
                            _Skel(color: shimmer, h: 22, w: 80),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Stock chip skeleton ────────────────────────────────
                        _Skel(color: shimmer, h: 24, w: 110, r: 20),
                        const SizedBox(height: 28),

                        // ── Section title ──────────────────────────────────────
                        _Skel(color: shimmer, h: 13, w: 70),
                        const SizedBox(height: 12),

                        // ── Description lines ──────────────────────────────────
                        ...[1.0, 1.0, 1.0, 0.6].map(
                              (fraction) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _Skel(
                              color: shimmer,
                              h: 12,
                              w: double.infinity,
                              widthFactor: fraction,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Attributes table skeleton ──────────────────────────
                        _Skel(color: shimmer, h: 13, w: 90),
                        const SizedBox(height: 10),
                        _Skel(color: shimmer, h: 100, w: double.infinity, r: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Bottom bar skeleton ────────────────────────────────────────────
            bottomNavigationBar: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: _Skel(color: shimmer, h: 56, r: 16),
            ),
          ),
        );
      },
    );
  }
}

// ── Skeleton box helper ───────────────────────────────────────────────────────

class _Skel extends StatelessWidget {
  final Color color;
  final double h;
  final double? w;
  final double r;

  /// Optionally shrink [w] by this factor (0.0–1.0). Used for partial lines.
  final double widthFactor;

  const _Skel({
    required this.color,
    required this.h,
    this.w,
    this.r = 7,
    this.widthFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget box = Container(
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    if (w != null && w != double.infinity) {
      box = SizedBox(width: w! * widthFactor, child: box);
    } else if (widthFactor < 1.0) {
      box = FractionallySizedBox(widthFactor: widthFactor, child: box);
    }

    return box;
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final ProductModel? product;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    this.product,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: product != null ? Text(product!.displayName) : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}