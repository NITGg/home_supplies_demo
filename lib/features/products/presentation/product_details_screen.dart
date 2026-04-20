import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/image_with_fallback.dart';
import '../../cart/manager/cart_cubit.dart';
import '../../cart/manager/cart_state.dart';
import '../../cart/presentation/cart_icon.dart';
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

  @override
  void initState() {
    super.initState();
    _cubit = ProductDetailCubit();
    _cubit.load(_id);
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
            ProductDetailLoading() =>
                _LoadingView(product: widget.product),
            ProductDetailError(:final message) => _ErrorView(
              message: message,
              product: widget.product,
              onRetry: () => _cubit.load(_id),
            ),
            ProductDetailLoaded(:final product) => _buildLoaded(product),
          };
        },
      ),
    );
  }

  Widget _buildLoaded(ProductModel product) {
    return Scaffold(
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
                  _StockChip(product: product),
                  const SizedBox(height: 20),

                  if (product.displayDescription.isNotEmpty) ...[
                    _SectionTitle(title: 'الوصف'),
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
                    _SectionTitle(title: 'المواصفات'),
                    const SizedBox(height: 8),
                    _AttributesTable(attributes: product.attributes),
                    const SizedBox(height: 20),
                  ],

                  if (product.units.isNotEmpty) ...[
                    _SectionTitle(title: 'وحدات الشراء'),
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
      bottomNavigationBar: _AddToCartBar(product: product),
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
    final item =
        state.data.cartItems.where((i) => i.spId == spId).firstOrNull;
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
//
// Visual states:
//   • Out of stock  → disabled full-width button
//   • qty == 0      → full-width "أضف إلى السلة" button  (with bounce on tap)
//   • qty >  0      → full-width quantity pill  (− qty +)
//   • busy          → full-width centered spinner

class _AddToCartBar extends StatefulWidget {
  final ProductModel product;

  const _AddToCartBar({required this.product});

  @override
  State<_AddToCartBar> createState() => _AddToCartBarState();
}

class _AddToCartBarState extends State<_AddToCartBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceScale;

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
        tween: Tween(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 0.96)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.96, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
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
    HapticFeedback.lightImpact();
    _bounceCtrl.forward(from: 0);
    try {
      await ctx.read<CartCubit>().addItem(
        spId: widget.product.spId ?? widget.product.id,
        quantity: 1,
      );
    } catch (_) {
      if (ctx.mounted) _showError(ctx);
    }
  }

  Future<void> _handleIncrement(BuildContext ctx) async {
    HapticFeedback.selectionClick();
    _bounceCtrl.forward(from: 0);
    try {
      await ctx
          .read<CartCubit>()
          .incrementItem(widget.product.spId ?? widget.product.id);
    } catch (_) {
      if (ctx.mounted) _showError(ctx);
    }
  }

  Future<void> _handleDecrement(BuildContext ctx) async {
    HapticFeedback.selectionClick();
    try {
      await ctx
          .read<CartCubit>()
          .decrementItem(widget.product.spId ?? widget.product.id);
    } catch (_) {
      if (ctx.mounted) _showError(ctx);
    }
  }

  void _showError(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('تعذّر تحديث السلة'),
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
          // Determine which child AnimatedSwitcher should show.
          final Widget content;

          if (product.isOutOfStock) {
            // ── Out of stock ───────────────────────────────────────────────
            content = _OutOfStockButton(key: const ValueKey('oos'));
          } else if (barState.isBusy) {
            // ── Busy (network in-flight) ───────────────────────────────────
            content = _BusyBar(
              key: const ValueKey('busy'),
              color: theme.colorScheme.primary,
            );
          } else if (barState.inCartQty == 0) {
            // ── Not yet in cart: big add button ────────────────────────────
            content = ScaleTransition(
              key: const ValueKey('add'),
              scale: _bounceScale,
              child: _AddButton(
                onTap: () => _handleAdd(ctx),
                theme: theme,
              ),
            );
          } else {
            // ── Already in cart: full-width quantity pill ──────────────────
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
            // ⚠️  Do NOT set switchInCurve / switchOutCurve to any curve that
            // overshoots [0, 1] (e.g. easeOutBack, elasticOut). Those curves
            // are applied to the raw `animation` value before it reaches
            // transitionBuilder, so FadeTransition.opacity would receive
            // values like 1.056 and crash with a parametric-value assertion.
            //
            // Overshoot is fine for *scale* (applied only inside the builder
            // below), but opacity must always stay in [0, 1].
            transitionBuilder: (child, animation) {
              // Scale: safe to overshoot — easeOutBack gives the pop feel.
              final scaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              );
              // Fade: must stay in [0, 1] — use a plain easeIn.
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
  const _OutOfStockButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: null, // disabled
      icon: const Icon(Icons.remove_shopping_cart_outlined),
      label: const Text(
        'نفد المخزون',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
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

  const _AddButton({required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_shopping_cart_rounded),
      label: const Text(
        'أضف إلى السلة',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          // ── Decrement ─────────────────────────────────────────────────────
          // Tapping at qty=1 calls decrementItem which removes the item —
          // the bar will animate back to the "Add" button automatically.
          _PillButton(
            icon: Icons.remove_rounded,
            onTap: onDecrement,
            enabled: true,
          ),

          // ── Animated count ────────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
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

          // ── Increment ─────────────────────────────────────────────────────
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
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade200,
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Colors.grey.shade700,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      actions: [
        AnimatedCartIcon(onTap: () => context.push('/cart')),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: images.isEmpty
            ? _placeholder(theme)
            : Stack(
          children: [
            ImageWithIconFallback(imageUrl: images[selectedIndex]),
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
                child: Image.network(e.value, fit: BoxFit.cover),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.isBestSeller || product.isFeatured)
          Wrap(
            spacing: 6,
            children: [
              if (product.isBestSeller)
                _Chip(label: 'الأكثر مبيعاً', color: Colors.amber.shade700),
              if (product.isFeatured)
                _Chip(label: 'مميز', color: theme.colorScheme.tertiary),
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

// ── Price section ─────────────────────────────────────────────────────────────

class _PriceSection extends StatelessWidget {
  final ProductModel product;
  const _PriceSection({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (product.hasOffer) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${product.offer!.toStringAsFixed(0)} ج.م',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${product.price.toStringAsFixed(0)} ج.م',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    }

    return Text(
      '${product.effectivePrice.toStringAsFixed(0)} ج.م',
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
    if (product.isOutOfStock) {
      return const _Chip(label: 'نفد المخزون', color: Colors.red);
    }
    if (product.isLowStock) {
      return _Chip(label: 'متبقي ${product.stock} فقط', color: Colors.orange);
    }
    return _Chip(label: 'متوفر (${product.stock})', color: Colors.green);
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
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  attr.key,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            '${u.displayName} — ${u.price} ج.م',
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
          Text('SKU: ${product.sku}'),
          if (product.barcode != null) Text('باركود: ${product.barcode}'),
          if (product.weight != null) Text('الوزن: ${product.weight} كجم'),
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
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

// ── Loading & error views ─────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final ProductModel? product;
  const _LoadingView({this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: product != null ? Text(product!.displayName) : null,
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

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
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}