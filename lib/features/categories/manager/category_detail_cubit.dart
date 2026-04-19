import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/utils/extract_error_message.dart';

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
    if (!isClosed) emit(const CategoryDetailLoading());

    var step = 'getCategoryById';
    try {
      final category = await _categoryRepository.getCategoryById(categoryId);

      step = 'getCategories (sub-categories)';
      final subCatResponse = await _categoryRepository.getCategories(
        parentId: categoryId,
        skip: 0,
        limit: 50,
      );

      step = 'getProducts (direct products)';
      final directProductsResponse = await _productRepository.getProducts(
        categoryId: categoryId,
        skip: 0,
        limit: _pageSize,
      );

      if (isClosed) return;

      step = 'parsing response';
      final subCategories = subCatResponse.categories as List;
      final sections = subCategories.map((sc) {
        return SubCategorySection(subCategory: sc);
      }).toList();

      final loaded = CategoryDetailLoaded(
        category: category,
        sections: sections,
        directProducts: directProductsResponse.products,
        directProductsHasMore:
        directProductsResponse.products.length
        < directProductsResponse.totalProducts,
        directProductsSkip: directProductsResponse.products.length,
      );

      if (!isClosed) emit(loaded);

      if (sections.isNotEmpty) {
        _loadAllSectionProducts(sections.map((s) => s.subCategory.id).toList());
      }
    } catch (e) {
      log('CategoryDetailCubit: ❌ Failed at step "$step" for category $categoryId');
      log('CategoryDetailCubit: Error → $e');
      if (!isClosed) emit(CategoryDetailError(extractErrorMessage(e)));
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
    if (isClosed) return;

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
    if (!isClosed) emit(current.copyWith(sections: updatedSections));

    try {
      final response = await _productRepository.getProducts(
        categoryId: subCategoryId,
        skip: skip,
        limit: _pageSize,
      );

      if (isClosed) return;

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

      if (!isClosed) emit(freshState.copyWith(sections: newSections));
    } catch (e) {
      log('CategoryDetailCubit: Error loading products for section $subCategoryId: $e');

      if (isClosed) return;

      final freshState = state;
      if (freshState is! CategoryDetailLoaded) return;

      final freshIndex = freshState.sections
          .indexWhere((s) => s.subCategory.id == subCategoryId);
      if (freshIndex == -1) return;

      final newSections = List<SubCategorySection>.from(freshState.sections);
      newSections[freshIndex] =
          newSections[freshIndex].copyWith(isLoading: false);
      if (!isClosed) emit(freshState.copyWith(sections: newSections));
    }
  }

  Future<void> loadMoreSectionProducts(int subCategoryId) =>
      _loadSectionProducts(subCategoryId);

  // ── Load more direct products ──────────────────────────────────────────────

  Future<void> loadMoreDirectProducts() async {
    if (isClosed) return;

    final current = state;
    if (current is! CategoryDetailLoaded) return;
    if (current.directProductsLoading || !current.directProductsHasMore) return;

    if (!isClosed) emit(current.copyWith(directProductsLoading: true));

    try {
      final response = await _productRepository.getProducts(
        categoryId: current.category.id,
        skip: current.directProductsSkip,
        limit: _pageSize,
      );

      if (isClosed) return;

      final freshState = state;
      if (freshState is! CategoryDetailLoaded) return;

      if (!isClosed) {
        emit(freshState.copyWith(
          directProducts: [...freshState.directProducts, ...response.products],
          directProductsLoading: false,
          directProductsSkip:
          freshState.directProductsSkip + response.products.length,
          directProductsHasMore:
          freshState.directProductsSkip + response.products.length
              < response.totalProducts,
        ));
      }
    } catch (e) {
      log('CategoryDetailCubit: Error loading more direct products: $e');

      if (isClosed) return;

      final freshState = state;
      if (freshState is! CategoryDetailLoaded) return;
      if (!isClosed) emit(freshState.copyWith(directProductsLoading: false));
    }
  }

  // ── Refresh ────────────────────────────────────────────────────────────────

  Future<void> refresh(int categoryId) => load(categoryId);
}