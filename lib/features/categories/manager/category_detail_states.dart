import 'package:equatable/equatable.dart';

import '../../products/data/models/product_model.dart';
import '../../suppliers/data/models/supplier_models.dart';
import '../data/models/category_models.dart';

// ── Sub-category section data ─────────────────────────────────────────────────

class SubCategorySection extends Equatable {
  final CategoryModel subCategory;
  final List<ProductModel> products;
  final bool isLoading;
  final bool hasMore;
  final int skip;

  const SubCategorySection({
    required this.subCategory,
    this.products = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.skip = 0,
  });

  SubCategorySection copyWith({
    CategoryModel? subCategory,
    List<ProductModel>? products,
    bool? isLoading,
    bool? hasMore,
    int? skip,
  }) {
    return SubCategorySection(
      subCategory: subCategory ?? this.subCategory,
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      skip: skip ?? this.skip,
    );
  }

  @override
  List<Object?> get props => [subCategory, products, isLoading, hasMore, skip];
}

// ── States ────────────────────────────────────────────────────────────────────

sealed class CategoryDetailState extends Equatable {
  const CategoryDetailState();

  @override
  List<Object?> get props => [];
}

class CategoryDetailInitial extends CategoryDetailState {
  const CategoryDetailInitial();
}

class CategoryDetailLoading extends CategoryDetailState {
  const CategoryDetailLoading();
}

/// Category loaded; sub-categories and products may still be loading.
class CategoryDetailLoaded extends CategoryDetailState {
  final CategoryModel category;
  final List<SubCategorySection> sections;

  /// The main supplier fetched alongside the category.  When non-null and the
  /// supplier has working-hours configured, a banner is shown at the top of
  /// the category detail screen.
  final SupplierModel? mainSupplier;

  /// Used when the category has no sub-categories – products belong directly.
  final List<ProductModel> directProducts;
  final bool directProductsLoading;
  final bool directProductsHasMore;
  final int directProductsSkip;

  const CategoryDetailLoaded({
    required this.category,
    required this.sections,
    this.mainSupplier,
    this.directProducts = const [],
    this.directProductsLoading = false,
    this.directProductsHasMore = true,
    this.directProductsSkip = 0,
  });

  bool get hasSections => sections.isNotEmpty;

  CategoryDetailLoaded copyWith({
    CategoryModel? category,
    List<SubCategorySection>? sections,
    SupplierModel? mainSupplier,
    bool clearMainSupplier = false,
    List<ProductModel>? directProducts,
    bool? directProductsLoading,
    bool? directProductsHasMore,
    int? directProductsSkip,
  }) {
    return CategoryDetailLoaded(
      category: category ?? this.category,
      sections: sections ?? this.sections,
      mainSupplier:
      clearMainSupplier ? null : (mainSupplier ?? this.mainSupplier),
      directProducts: directProducts ?? this.directProducts,
      directProductsLoading:
      directProductsLoading ?? this.directProductsLoading,
      directProductsHasMore:
      directProductsHasMore ?? this.directProductsHasMore,
      directProductsSkip: directProductsSkip ?? this.directProductsSkip,
    );
  }

  @override
  List<Object?> get props => [
    category,
    sections,
    mainSupplier,
    directProducts,
    directProductsLoading,
    directProductsHasMore,
    directProductsSkip,
  ];
}

class CategoryDetailError extends CategoryDetailState {
  final String message;

  const CategoryDetailError(this.message);

  @override
  List<Object?> get props => [message];
}