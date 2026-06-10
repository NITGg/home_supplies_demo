import 'package:equatable/equatable.dart';

import '../data/models/supplier_models.dart';

// ── Supplier list states (for the horizontal strip) ───────────────────────────

sealed class SuppliersState extends Equatable {
  const SuppliersState();

  @override
  List<Object?> get props => [];
}

class SuppliersInitial extends SuppliersState {
  const SuppliersInitial();
}

class SuppliersLoading extends SuppliersState {
  const SuppliersLoading();
}

class SuppliersLoaded extends SuppliersState {
  final List<SupplierModel> suppliers;

  /// Number of suppliers already fetched — used as the `skip` for the next page.
  final int skip;

  /// Whether more pages are available from the backend.
  final bool hasMore;

  /// Whether the next page is currently being fetched (for a trailing
  /// loading indicator at the end of the strip).
  final bool isLoadingMore;

  const SuppliersLoaded({
    required this.suppliers,
    this.skip = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  SuppliersLoaded copyWith({
    List<SupplierModel>? suppliers,
    int? skip,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return SuppliersLoaded(
      suppliers: suppliers ?? this.suppliers,
      skip: skip ?? this.skip,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [suppliers, skip, hasMore, isLoadingMore];
}

class SuppliersError extends SuppliersState {
  final String message;

  const SuppliersError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Supplier detail states (for the supplier detail screen) ───────────────────

/// One category section inside the supplier detail screen.
class SupplierCategorySection extends Equatable {
  final SupplierCategoryModel category;
  final List<dynamic> products; // ProductModel list
  final bool isLoading;
  final bool hasMore;
  final int skip;

  const SupplierCategorySection({
    required this.category,
    this.products = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.skip = 0,
  });

  SupplierCategorySection copyWith({
    SupplierCategoryModel? category,
    List<dynamic>? products,
    bool? isLoading,
    bool? hasMore,
    int? skip,
  }) {
    return SupplierCategorySection(
      category: category ?? this.category,
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      skip: skip ?? this.skip,
    );
  }

  @override
  List<Object?> get props => [category, products, isLoading, hasMore, skip];
}

sealed class SupplierDetailState extends Equatable {
  const SupplierDetailState();

  @override
  List<Object?> get props => [];
}

class SupplierDetailInitial extends SupplierDetailState {
  const SupplierDetailInitial();
}

class SupplierDetailLoading extends SupplierDetailState {
  const SupplierDetailLoading();
}

class SupplierDetailLoaded extends SupplierDetailState {
  final SupplierModel supplier;
  final List<SupplierCategorySection> sections;

  const SupplierDetailLoaded({
    required this.supplier,
    required this.sections,
  });

  SupplierDetailLoaded copyWith({
    SupplierModel? supplier,
    List<SupplierCategorySection>? sections,
  }) {
    return SupplierDetailLoaded(
      supplier: supplier ?? this.supplier,
      sections: sections ?? this.sections,
    );
  }

  @override
  List<Object?> get props => [supplier, sections];
}

class SupplierDetailError extends SupplierDetailState {
  final String message;

  const SupplierDetailError(this.message);

  @override
  List<Object?> get props => [message];
}