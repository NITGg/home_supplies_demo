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
      // Phase 1: category + sub-categories — emit immediately so UI renders.
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

      if (!isClosed) emit(CategoryDetailLoaded(category: category, sections: sections));

      // Phase 2: suppliers + products run fully in parallel —
      // no supplier_id needed for products since the backend now returns
      // all active suppliers when supplier_id is omitted.
      await Future.wait([
        _fetchAndUpdateSuppliers(),
        if (sections.isNotEmpty)
          _loadAllSectionProducts(sections.map((s) => s.subCategory.id).toList())
        else
          _loadDirectProducts(categoryId, isInitial: true),
      ]);

      // Phase 3: trim suppliers list to only those with products here.
      _filterSuppliersToActive();
    } catch (e) {
      dLog('CategoryDetailCubit: ❌ load failed → $e');
      if (!isClosed) emit(CategoryDetailError(extractErrorMessage(e)));
    }
  }

  // ── Fetch all active suppliers and update state ────────────────────────────

  Future<void> _fetchAndUpdateSuppliers() async {
    try {
      final r = await _supplierRepository.getSuppliers();
      if (isClosed) return;
      final current = state;
      if (current is CategoryDetailLoaded) {
        emit(current.copyWith(suppliers: r.suppliers));
      }
    } catch (e) {
      dLog('CategoryDetailCubit: suppliers fetch failed → $e');
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
      emit(current.copyWith(suppliersReady: true));
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
