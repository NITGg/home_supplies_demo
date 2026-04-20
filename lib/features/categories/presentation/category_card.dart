import 'package:flutter/material.dart';
import 'package:tawreedat_go/core/widgets/image_with_fallback.dart';
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
      CategoryCardStyle.compact => _CompactCard(category: category, onTap: onTap),
      CategoryCardStyle.regular => _RegularCard(category: category, onTap: onTap),
    };
  }
}

// ── Regular card: full image cover + small name at top center ─────────────────

class _RegularCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback? onTap;

  const _RegularCard({required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full cover image ──────────────────────────────────────────
            _buildImage(category.imageUrl ?? category.iconUrl),

            // ── Top center name label ─────────────────────────────────────
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String? url) {
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          category.displayName.isNotEmpty
              ? category.displayName[0].toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}

// ── Compact card: circle cover with iconUrl + name below ──────────────────────

class _CompactCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback? onTap;

  const _CompactCard({required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    final iconUrl = category.iconUrl ?? category.imageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Circle image ─────────────────────────────────────────────────
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: _buildIcon(iconUrl),
          ),

          const SizedBox(height: 6),

          // ── Name below ───────────────────────────────────────────────────
          Text(
            category.displayName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(String? url) {
    if (url != null && url.isNotEmpty) {
      return ImageWithIconFallback(imageUrl: url,fit: BoxFit.cover,);
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          category.displayName.isNotEmpty
              ? category.displayName[0].toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}