import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/products/presentation/quantity_selector.dart';


import '../../cart/manager/cart_cubit.dart';
import '../data/models/product_model.dart';
import '../manager/product_detail_cubit.dart';
import '../manager/product_details_states.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel? product;
  final int? productId;

  const ProductDetailScreen({
    super.key,
    this.product,
    this.productId,
  }) : assert(product != null || productId != null);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductDetailCubit _cubit;
  int _quantity = 0;
  int _selectedImageIndex = 0;

  int get _id => widget.product?.id ?? widget.productId!;

  @override
  void initState() {
    super.initState();
    _cubit = ProductDetailCubit();
    // If we already have the product from navigation, seed it immediately
    if (widget.product != null) {
      _cubit.load(_id); // still fetches full details (attributes etc.)
    } else {
      _cubit.load(_id);
    }
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
            ProductDetailInitial() || ProductDetailLoading() =>
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
                  // ── Name & badges ────────────────────────────────────────
                  _NameRow(product: product),
                  const SizedBox(height: 12),

                  // ── Price ────────────────────────────────────────────────
                  _PriceSection(product: product),
                  const SizedBox(height: 12),

                  // ── Stock indicator ──────────────────────────────────────
                  _StockChip(product: product),
                  const SizedBox(height: 20),

                  // ── Description ──────────────────────────────────────────
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

                  // ── Attributes ───────────────────────────────────────────
                  if (product.attributes.isNotEmpty) ...[
                    _SectionTitle(title: 'المواصفات'),
                    const SizedBox(height: 8),
                    _AttributesTable(attributes: product.attributes),
                    const SizedBox(height: 20),
                  ],

                  // ── Units ────────────────────────────────────────────────
                  if (product.units.isNotEmpty) ...[
                    _SectionTitle(title: 'وحدات الشراء'),
                    const SizedBox(height: 8),
                    _UnitsRow(units: product.units),
                    const SizedBox(height: 20),
                  ],

                  // ── Meta info ────────────────────────────────────────────
                  _MetaInfo(product: product),

                  const SizedBox(height: 100), // bottom bar clearance
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom add-to-cart bar ─────────────────────────────────────────
      bottomNavigationBar: _AddToCartBar(
        product: product,
        quantity: _quantity,
        onIncrement: () {
          if (!product.isOutOfStock) setState(() => _quantity++);
        },
        onDecrement: () {
          if (_quantity > 0) setState(() => _quantity--);
        },
        onAddToCart: () async {
          final qty = _quantity == 0 ? 1 : _quantity;
          if (_quantity == 0) setState(() => _quantity = 1);

          try {
            await context.read<CartCubit>().addItem(
              spId: product.spId??product.id,
              quantity: qty,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تمت إضافة ${product.displayName} إلى السلة'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('تعذّرت الإضافة إلى السلة'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        },
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
      flexibleSpace: FlexibleSpaceBar(
        background: images.isEmpty
            ? _placeholder(theme)
            : Stack(
          children: [
            // Main image
            Image.network(
              images[selectedIndex],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => _placeholder(theme),
            ),
            // Thumbnail row at bottom
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
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white38,
                  width: isSelected ? 2 : 1,
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
                _Chip(
                    label: 'مميز', color: theme.colorScheme.tertiary),
            ],
          ),
        const SizedBox(height: 4),
        Text(
          product.displayName,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
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
      return _Chip(
        label: 'متبقي ${product.stock} فقط',
        color: Colors.orange,
      );
    }
    return _Chip(
      label: 'متوفر (${product.stock})',
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
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
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
      style:
      theme.textTheme.bodySmall!.copyWith(color: Colors.grey.shade600),
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

// ── Add to cart bottom bar ────────────────────────────────────────────────────

class _AddToCartBar extends StatelessWidget {
  final ProductModel product;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onAddToCart;

  const _AddToCartBar({
    required this.product,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          QuantitySelector(
            quantity: quantity,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
            maxQuantity: product.isOutOfStock ? 0 : product.maxAmountForOneOrder,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: product.isOutOfStock ? null : onAddToCart,
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text(
                product.isOutOfStock ? 'نفد المخزون' : 'أضف إلى السلة',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
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
      appBar: AppBar(title: product != null ? Text(product!.displayName) : null),
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
      appBar: AppBar(title: product != null ? Text(product!.displayName) : null),
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