import 'package:flutter_bloc/flutter_bloc.dart';

import '../../products/data/repo/product_repo.dart';
import '../data/repo/category_repo.dart';
import 'category_detail_states.dart';


class CategoryDetailCubit extends Cubit<CategoryDetailState> {
  final CategoryRepository _categoryRepository;
  final ProductRepository _productRepository;

  static const int _pageSize = 12;

  CategoryDetailCubit({
    CategoryRepository? categoryRepository,
    ProductRepository? productRepository,
  })  : _categoryRepository = categoryRepository ?? CategoryRepositoryImpl(),
        _productRepository = productRepository ?? ProductRepositoryImpl(),
        super(const CategoryDetailInitial());

  // ── Load full category detail ──────────────────────────────────────────────

  Future<void> load(int categoryId) async {
    emit(const CategoryDetailLoading());

    try {
      // 1. Fetch the category itself
      final category = await _categoryRepository.getCategoryById(categoryId);

      // 2. Fetch sub-categories in parallel with first product page
      final subCatFuture = _categoryRepository.getCategories(
        parentId: categoryId,
        skip: 0,
        limit: 50, // load all sub-cats at once; unlikely to be hundreds
      );

      // 3. Also load direct products (category has no sub-cats OR as fallback)
      final directProductsFuture = _productRepository.getProducts(
        categoryId: categoryId,
        skip: 0,
        limit: _pageSize,
      );

      final results = await Future.wait([subCatFuture, directProductsFuture]);
      final subCatResponse = results[0] as dynamic;
      final directProductsResponse = results[1] as dynamic;

      final subCategories = subCatResponse.categories as List;

      // Build sections for each sub-category (without products yet)
      final sections = subCategories.map((sc) {
        return SubCategorySection(subCategory: sc);
      }).toList();

      final loaded = CategoryDetailLoaded(
        category: category,
        sections: sections,
        directProducts: directProductsResponse.products,
        directProductsHasMore:
        directProductsResponse.products.length < directProductsResponse.totalProducts,
        directProductsSkip: directProductsResponse.products.length,
      );

      emit(loaded);

      // 4. Now fire off product loads for each sub-category in parallel
      if (sections.isNotEmpty) {
        _loadAllSectionProducts(sections.map((s) => s.subCategory.id).toList());
      }
    } catch (e) {
      emit(CategoryDetailError(_parseError(e)));
    }
  }

  // ── Load products for all sub-category sections ───────────────────────────

  Future<void> _loadAllSectionProducts(List<int> subCategoryIds) async {
    await Future.wait(
      subCategoryIds.map((id) => _loadSectionProducts(id, isInitial: true)),
    );
  }

  Future<void> _loadSectionProducts(int subCategoryId,
      {bool isInitial = false}) async {
    final current = state;
    if (current is! CategoryDetailLoaded) return;

    final sectionIndex =
    current.sections.indexWhere((s) => s.subCategory.id == subCategoryId);
    if (sectionIndex == -1) return;

    final section = current.sections[sectionIndex];
    if (section.isLoading) return;
    if (!isInitial && !section.hasMore) return;

    final skip = isInitial ? 0 : section.skip;

    // Mark loading
    final updatedSections = List<SubCategorySection>.from(current.sections);
    updatedSections[sectionIndex] = section.copyWith(isLoading: true);
    emit(current.copyWith(sections: updatedSections));

    try {
      final response = await _productRepository.getProducts(
        categoryId: subCategoryId,
        skip: skip,
        limit: _pageSize,
      );

      final freshState = state;
      if (freshState is! CategoryDetailLoaded) return;

      final freshIndex = freshState.sections
          .indexWhere((s) => s.subCategory.id == subCategoryId);
      if (freshIndex == -1) return;

      final freshSection = freshState.sections[freshIndex];
      final newProducts = isInitial
          ? response.products
          : [...freshSection.products, ...response.products];
      final newSkip = skip + response.products.length;

      final newSections = List<SubCategorySection>.from(freshState.sections);
      newSections[freshIndex] = freshSection.copyWith(
        products: newProducts,
        isLoading: false,
        hasMore: newSkip < response.totalProducts,
        skip: newSkip,
      );

      emit(freshState.copyWith(sections: newSections));
    } catch (_) {
      final freshState = state;
      if (freshState is! CategoryDetailLoaded) return;
      final freshIndex = freshState.sections
          .indexWhere((s) => s.subCategory.id == subCategoryId);
      if (freshIndex == -1) return;

      final newSections = List<SubCategorySection>.from(freshState.sections);
      newSections[freshIndex] =
          newSections[freshIndex].copyWith(isLoading: false);
      emit(freshState.copyWith(sections: newSections));
    }
  }

  Future<void> loadMoreSectionProducts(int subCategoryId) =>
      _loadSectionProducts(subCategoryId);

  // ── Load more direct products ──────────────────────────────────────────────

  Future<void> loadMoreDirectProducts() async {
    final current = state;
    if (current is! CategoryDetailLoaded) return;
    if (current.directProductsLoading || !current.directProductsHasMore) return;

    emit(current.copyWith(directProductsLoading: true));

    try {
      final response = await _productRepository.getProducts(
        categoryId: current.category.id,
        skip: current.directProductsSkip,
        limit: _pageSize,
      );

      final freshState = state;
      if (freshState is! CategoryDetailLoaded) return;

      emit(freshState.copyWith(
        directProducts: [...freshState.directProducts, ...response.products],
        directProductsLoading: false,
        directProductsSkip:
        freshState.directProductsSkip + response.products.length,
        directProductsHasMore: freshState.directProductsSkip +
            response.products.length <
            response.totalProducts,
      ));
    } catch (_) {
      final freshState = state;
      if (freshState is! CategoryDetailLoaded) return;
      emit(freshState.copyWith(directProductsLoading: false));
    }
  }

  // ── Refresh ────────────────────────────────────────────────────────────────

  Future<void> refresh(int categoryId) => load(categoryId);

  String _parseError(Object e) =>
      e.toString().replaceFirst('Exception: ', '');
}