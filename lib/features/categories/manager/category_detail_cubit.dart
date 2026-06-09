import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../../products/data/repo/product_repo.dart';
import '../../suppliers/data/repo/supplier_repo.dart';
import '../data/repo/category_repo.dart';
import 'category_detail_states.dart';

class CategoryDetailCubit extends Cubit<CategoryDetailState> {
  final CategoryRepository _categoryRepository;
  final ProductRepository _productRepository;
  final SupplierRepository _supplierRepository;

  static const int _pageSize = 10;

  CategoryDetailCubit({
    CategoryRepository? categoryRepository,
    ProductRepository? productRepository,
    SupplierRepository? supplierRepository,
  })  : _categoryRepository = categoryRepository ?? CategoryRepositoryImpl(),
        _productRepository = productRepository ?? ProductRepositoryImpl(),
        _supplierRepository = supplierRepository ?? SupplierRepositoryImpl(),
        super(const CategoryDetailInitial());

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load(int categoryId) async {
    if (!isClosed) emit(const CategoryDetailLoading());

    try {
      // Fire the suppliers HTTP request immediately so it runs in parallel with
      // the category + sub-categories fetch. We deliberately start the raw
      // Future here rather than calling _fetchAndUpdateSuppliers(), because
      // that helper reads state — and state won't be CategoryDetailLoaded until
      // after the category fetch completes. The result is applied below, after
      // the loaded state has been emitted.
      final suppliersRequest = _supplierRepository.getSuppliers();

      // Fetch category detail and its sub-categories in parallel.
      final results = await Future.wait([
        _categoryRepository.getCategoryById(categoryId),
        _categoryRepository.getCategories(
          parentId: categoryId,
          skip: 0,
          limit: 50,
        ),
      ]);

      if (isClosed) return;

      final category = results[0] as dynamic;
      final subCatResponse = results[1] as dynamic;
      final subCategories = subCatResponse.categories as List;
      final sections = subCategories
          .map((sc) => SubCategorySection(subCategory: sc))
          .toList();

      // State is now CategoryDetailLoaded — safe to apply suppliers when ready.
      if (!isClosed) emit(CategoryDetailLoaded(category: category, sections: sections));

      // Products + supplier application run in parallel.
      await Future.wait([
        suppliersRequest.then((r) {
          if (isClosed) return;
          final current = state;
          if (current is CategoryDetailLoaded) {
            emit(current.copyWith(suppliers: r.suppliers));
          }
        }).catchError((e) {
          dLog('CategoryDetailCubit: suppliers fetch failed → $e');
        }),
        if (sections.isNotEmpty)
          _loadAllSectionProducts(sections.map((s) => s.subCategory.id).toList())
        else
          _loadDirectProducts(categoryId, isInitial: true),
      ]);

      // Trim suppliers to only those that have products in this category.
      _filterSuppliersToActive();
    } catch (e) {
      dLog('CategoryDetailCubit: ❌ load failed → $e');
      if (!isClosed) emit(CategoryDetailError(extractErrorMessage(e)));
    }
  }

  // ── Filter suppliers to those with at least one product here ──────────────

  void _filterSuppliersToActive() {
    if (isClosed) return;
    final current = state;
    if (current is! CategoryDetailLoaded) return;

    final activeIds = <int>{
      ...current.sections
          .expand((s) => s.products)
          .map((p) => p.supplierId)
          .whereType<int>(),
      ...current.directProducts
          .map((p) => p.supplierId)
          .whereType<int>(),
    };

    if (activeIds.isEmpty) {
      emit(current.copyWith(suppliers: [], suppliersReady: true));
      return;
    }

    final filtered =
        current.suppliers.where((s) => activeIds.contains(s.id)).toList();
    emit(current.copyWith(suppliers: filtered, suppliersReady: true));
  }

  // ── Section products ───────────────────────────────────────────────────────

  Future<void> _loadAllSectionProducts(List<int> subCategoryIds) async {
    await Future.wait(
      subCategoryIds.map((id) => _loadSectionProducts(id, isInitial: true)),
    );
  }

  Future<void> _loadSectionProducts(
    int subCategoryId, {
    bool isInitial = false,
  }) async {
    if (isClosed) return;
    final current = state;
    if (current is! CategoryDetailLoaded) return;

    final idx =
        current.sections.indexWhere((s) => s.subCategory.id == subCategoryId);
    if (idx == -1) return;

    final section = current.sections[idx];
    if (section.isLoading) return;
    if (!isInitial && !section.hasMore) return;

    final skip = isInitial ? 0 : section.skip;

    final updatedSections = List<SubCategorySection>.from(current.sections);
    updatedSections[idx] = section.copyWith(isLoading: true);
    if (!isClosed) emit(current.copyWith(sections: updatedSections));

    try {
      final response = await _productRepository.getProducts(
        categoryId: subCategoryId,
        skip: skip,
        limit: _pageSize,
      );

      if (isClosed) return;
      final fresh = state;
      if (fresh is! CategoryDetailLoaded) return;

      final freshIdx =
          fresh.sections.indexWhere((s) => s.subCategory.id == subCategoryId);
      if (freshIdx == -1) return;

      final freshSection = fresh.sections[freshIdx];
      final newProducts = isInitial
          ? response.products
          : [...freshSection.products, ...response.products];
      final newSkip = skip + response.products.length;

      final newSections = List<SubCategorySection>.from(fresh.sections);
      newSections[freshIdx] = freshSection.copyWith(
        products: newProducts,
        isLoading: false,
        hasMore: newSkip < response.totalProducts,
        skip: newSkip,
      );
      if (!isClosed) emit(fresh.copyWith(sections: newSections));
    } catch (e) {
      dLog('CategoryDetailCubit: section $subCategoryId failed → $e');
      if (isClosed) return;
      final fresh = state;
      if (fresh is! CategoryDetailLoaded) return;
      final freshIdx =
          fresh.sections.indexWhere((s) => s.subCategory.id == subCategoryId);
      if (freshIdx == -1) return;
      final newSections = List<SubCategorySection>.from(fresh.sections);
      newSections[freshIdx] = newSections[freshIdx].copyWith(isLoading: false);
      if (!isClosed) emit(fresh.copyWith(sections: newSections));
    }
  }

  Future<void> loadMoreSectionProducts(int subCategoryId) =>
      _loadSectionProducts(subCategoryId);

  // ── Direct products (leaf category — no sub-categories) ───────────────────

  Future<void> _loadDirectProducts(int categoryId,
      {bool isInitial = false}) async {
    if (isClosed) return;
    final current = state;
    if (current is! CategoryDetailLoaded) return;
    if (current.directProductsLoading) return;

    if (!isClosed) emit(current.copyWith(directProductsLoading: true));

    try {
      final skip = isInitial ? 0 : current.directProductsSkip;
      final response = await _productRepository.getProducts(
        categoryId: categoryId,
        skip: skip,
        limit: _pageSize,
      );

      if (isClosed) return;
      final fresh = state;
      if (fresh is! CategoryDetailLoaded) return;

      final newProducts = isInitial
          ? response.products
          : [...fresh.directProducts, ...response.products];
      final newSkip = skip + response.products.length;

      if (!isClosed) {
        emit(fresh.copyWith(
          directProducts: newProducts,
          directProductsLoading: false,
          directProductsHasMore: newSkip < response.totalProducts,
          directProductsSkip: newSkip,
        ));
      }
    } catch (e) {
      dLog('CategoryDetailCubit: direct products failed → $e');
      if (isClosed) return;
      final fresh = state;
      if (fresh is! CategoryDetailLoaded) return;
      if (!isClosed) emit(fresh.copyWith(directProductsLoading: false));
    }
  }

  Future<void> loadMoreDirectProducts() async {
    final current = state;
    if (current is! CategoryDetailLoaded) return;
    if (current.directProductsLoading || !current.directProductsHasMore) return;
    await _loadDirectProducts(current.category.id);
  }

  // ── Refresh ────────────────────────────────────────────────────────────────

  Future<void> refresh(int categoryId) => load(categoryId);
}
