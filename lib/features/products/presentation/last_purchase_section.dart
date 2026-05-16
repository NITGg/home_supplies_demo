import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';
import 'package:tawreedat_go/features/products/presentation/product_card.dart';
import 'package:tawreedat_go/features/products/presentation/product_secttion_skeleton.dart';

import '../../../core/utils/logger.dart';
import '../../../core/utils/secure_storage_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../products/data/models/product_model.dart';
import '../../products/data/repo/product_repo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class LastPurchasedSection extends StatefulWidget {
  final bool isGuest;

  /// Delay before the first API call — used for staggered section loading.
  final Duration loadDelay;

  const LastPurchasedSection({
    super.key,
    this.isGuest = false,
    this.loadDelay = Duration.zero,
  });

  @override
  State<LastPurchasedSection> createState() => _LastPurchasedSectionState();
}

class _LastPurchasedSectionState extends State<LastPurchasedSection> {
  static const int _pageSize = 5;

  final ProductRepository _repo = ProductRepositoryImpl();
  final ScrollController _scrollController = ScrollController();

  List<ProductModel> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _skip = 0;
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isGuest) {
      if (widget.loadDelay == Duration.zero) {
        _load();
      } else {
        Future.delayed(widget.loadDelay, () {
          if (mounted) _load();
        });
      }
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.isGuest) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.isGuest) return;
    // Guard against renders that fire before the guest flag is set
    final token = await SecureStorageService().getToken();
    if (token == null || token.isEmpty) return;
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final response = await _repo.getProducts(
        skip: _skip,
        limit: _pageSize,
        isLastPurchased: true,
      );

      if (!mounted) return;

      setState(() {
        _products = [..._products, ...response.products];
        _skip += response.products.length;
        _hasMore = _skip < response.totalProducts;
        _isLoading = false;
        _initialLoadDone = true;
      });
    } catch (e) {
      dLog('[LastPurchasedSection] error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _initialLoadDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guests never see this section — skip even the skeleton
    if (widget.isGuest) return const SizedBox.shrink();

    // Show skeleton while the first load is in progress
    if (!_initialLoadDone) return const ProductSectionSkeleton();

    // Nothing to show — collapse entirely
    if (_products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Section label + View All ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.purchasedBefore,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/last-purchased'),
                child: Text(
                  AppLocalizations.of(context)!.viewAll,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.kPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Horizontal list ───────────────────────────────────────────────
        SizedBox(
          height: 300,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _products.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _products.length) {
                return const ProductSectionLoadingCard();
              }
              final product = _products[index];
              return SizedBox(
                width: 160,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ProductCard(
                    product: product,
                    onTap: () => context.push(
                      '/products/${product.id}',
                      extra: product,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}