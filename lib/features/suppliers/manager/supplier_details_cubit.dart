
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../../products/data/repo/product_repo.dart';
import '../data/repo/supplier_repo.dart';
import 'supplier_states.dart';

class SupplierDetailCubit extends Cubit<SupplierDetailState> {
  final SupplierRepository _supplierRepository;
  final ProductRepository _productRepository;

  static const int _pageSize = 5;

  SupplierDetailCubit({
    SupplierRepository? supplierRepository,
    ProductRepository? productRepository,
  })  : _supplierRepository =
      supplierRepository ?? SupplierRepositoryImpl(),
        _productRepository =
            productRepository ?? ProductRepositoryImpl(),
        super(const SupplierDetailInitial());

  // ── Load supplier detail + categories + initial products ──────────────────

  /// [filterCategoryId] — when non-null (opened from a category page) only
  /// that one category section is shown, ignoring all others.
  Future<void> load(int supplierId, {int? filterCategoryId}) async {
    if (!isClosed) emit(const SupplierDetailLoading());

    var step = 'getSupplierById';
    try {
      final supplier =
      await _supplierRepository.getSupplierById(supplierId);

      step = 'getSupplierCategories';
      final catResponse =
      await _supplierRepository.getSupplierCategories(supplierId);

      if (isClosed) return;

      // When opened from a category page, show only that category's section.
      final categories = filterCategoryId != null
          ? catResponse.categories
          .where((c) => c.id == filterCategoryId)
          .toList()
          : catResponse.categories;

      final sections = categories
          .map((c) => SupplierCategorySection(category: c))
          .toList();

      if (!isClosed) {
        emit(SupplierDetailLoaded(supplier: supplier, sections: sections));
      }

      // Kick off initial product load for every section in parallel.
      if (sections.isNotEmpty) {
        await Future.wait(
          sections.map((s) =>
              _loadSectionProducts(supplierId, s.category.id,
                  isInitial: true)),
        );
      }
    } catch (e) {
      dLog('SupplierDetailCubit: ❌ Failed at "$step" for supplier $supplierId → $e');
      if (!isClosed) emit(SupplierDetailError(extractErrorMessage(e)));
    }
  }

  // ── Section product loading ───────────────────────────────────────────────

  Future<void> _loadSectionProducts(
      int supplierId,
      int categoryId, {
        bool isInitial = false,
      }) async {
    if (isClosed) return;

    final current = state;
    if (current is! SupplierDetailLoaded) return;

    final idx =
    current.sections.indexWhere((s) => s.category.id == categoryId);
    if (idx == -1) return;

    final section = current.sections[idx];
    if (section.isLoading) return;
    if (!isInitial && !section.hasMore) return;

    final skip = isInitial ? 0 : section.skip;

    // Mark section as loading.
    final updatedSections =
    List<SupplierCategorySection>.from(current.sections);
    updatedSections[idx] = section.copyWith(isLoading: true);
    if (!isClosed) emit(current.copyWith(sections: updatedSections));

    try {
      final response = await _productRepository.getProducts(
        categoryId: categoryId,
        skip: skip,
        limit: _pageSize,
        supplierId: supplierId,
      );

      if (isClosed) return;

      final fresh = state;
      if (fresh is! SupplierDetailLoaded) return;

      final freshIdx =
      fresh.sections.indexWhere((s) => s.category.id == categoryId);
      if (freshIdx == -1) return;

      final freshSection = fresh.sections[freshIdx];
      final newProducts = isInitial
          ? response.products
          : [...freshSection.products, ...response.products];
      final newSkip = skip + response.products.length;

      final newSections =
      List<SupplierCategorySection>.from(fresh.sections);
      newSections[freshIdx] = freshSection.copyWith(
        products: newProducts,
        isLoading: false,
        hasMore: newSkip < response.totalProducts,
        skip: newSkip,
      );

      if (!isClosed) emit(fresh.copyWith(sections: newSections));
    } catch (e) {
      dLog('SupplierDetailCubit: Error loading products for category $categoryId: $e');

      if (isClosed) return;

      final fresh = state;
      if (fresh is! SupplierDetailLoaded) return;

      final freshIdx =
      fresh.sections.indexWhere((s) => s.category.id == categoryId);
      if (freshIdx == -1) return;

      final newSections =
      List<SupplierCategorySection>.from(fresh.sections);
      newSections[freshIdx] =
          newSections[freshIdx].copyWith(isLoading: false);
      if (!isClosed) emit(fresh.copyWith(sections: newSections));
    }
  }

  Future<void> loadMoreSectionProducts(
      int supplierId, int categoryId) =>
      _loadSectionProducts(supplierId, categoryId);

  Future<void> refresh(int supplierId, {int? filterCategoryId}) =>
      load(supplierId, filterCategoryId: filterCategoryId);
}