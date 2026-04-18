import 'package:flutter/material.dart';

import '../data/models/category_models.dart';


enum CategoryCardStyle { compact, regular }

class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback? onTap;
  final CategoryCardStyle style;

  const CategoryCard({
    super.key,
    required this.category,
    this.onTap,
    this.style = CategoryCardStyle.regular,
  });

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      CategoryCardStyle.compact => _CompactCard(
        category: category,
        onTap: onTap,
      ),
      CategoryCardStyle.regular => _RegularCard(
        category: category,
        onTap: onTap,
      ),
    };
  }
}

// ── Regular card (few categories) ────────────────────────────────────────────

class _RegularCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback? onTap;

  const _RegularCard({required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: _CategoryImage(
                imageUrl: category.imageUrl ?? category.iconUrl,
                label: category.displayName,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.displayName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (category.displayDescription.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      category.displayDescription,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact card (many categories) ───────────────────────────────────────────

class _CompactCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback? onTap;

  const _CompactCard({required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer,
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _CategoryImage(
              imageUrl: category.imageUrl ?? category.iconUrl,
              label: category.displayName,
              iconSize: 28,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              category.displayName,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared image widget ───────────────────────────────────────────────────────

class _CategoryImage extends StatelessWidget {
  final String? imageUrl;
  final String label;
  final double iconSize;

  const _CategoryImage({
    this.imageUrl,
    required this.label,
    this.iconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: Text(
        label.isNotEmpty ? label[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: iconSize * 0.8,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}