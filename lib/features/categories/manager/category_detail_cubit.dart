import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/utils/app_dynamic_settings.dart';
import 'package:tawreedat_go/core/utils/extract_error_message.dart';
import '../../products/data/repo/product_repo.dart';
import '../../suppliers/data/models/supplier_models.dart';
import '../../suppliers/data/repo/supplier_repo.dart';
import '../data/repo/category_repo.dart';
import 'category_detail_states.dart';

class CategoryDetailCubit extends Cubit<CategoryDetailState> {
  final CategoryRepository _categoryRepository;
  final ProductRepository _productRepository;
  final SupplierRepository _supplierRepository;

  static const int _pageSize = 5;

  CategoryDetailCubit({
    CategoryRepository? categoryRepository,
    ProductRepository? productRepository,
    SupplierRepository? supplierRepository,
  })  : _categoryRepository = categoryRepository ?? CategoryRepositoryImpl(),
        _productRepository = productRepository ?? ProductRepositoryImpl(),
        _supplierRepository = supplierRepository ?? SupplierRepositoryImpl(),
        super(const CategoryDetailInitial());

  // ── Load full category detail ──────────────────────────────────────────────

  Future<void> load(int categoryId) async {
    if (!isClosed) emit(const CategoryDetailLoading());

    var step = 'parallel fetch';
    try {
      // Run category detail, sub-categories, first page of products, and the
      // main supplier all in parallel so there is only one network round-trip.
      final results = await Future.wait([
        _categoryRepository.getCategoryById(categoryId),           // [0]
        _categoryRepository.getCategories(                         // [1]
          parentId: categoryId,
          skip: 0,
          limit: 50,
        ),
        _productRepository.getProducts(                            // [2]
          categoryId: categoryId,
          skip: 0,
          limit: _pageSize,
        ),
        _supplierRepository                                        // [3]
            .getSupplierById(AppSettings.kMainSupplierId)
            .then<SupplierModel?>((s) => s)
            .catchError((e) {
          log('CategoryDetailCubit: Could not fetch main supplier → $e');
          return null;
        }),
      ]);

      if (isClosed) return;

      step = 'parsing response';
      final category = results[0] as dynamic; // CategoryModel
      final subCatResponse = results[1] as dynamic; // CategoriesResponseModel
      final directProductsResponse = results[2] as dynamic; // ProductsResponseModel
      final mainSupplier = results[3] as SupplierModel?;

      final subCategories = subCatResponse.categories as List;
      final sections = subCategories
          .map((sc) => SubCategorySection(subCategory: sc))
          .toList();

      final loaded = CategoryDetailLoaded(
        category: category,
        sections: sections,
        mainSupplier: mainSupplier,
        directProducts: directProductsResponse.products,
        directProductsHasMore: directProductsResponse.products.length <
            directProductsResponse.totalProducts,
        directProductsSkip: directProductsResponse.products.length,
      );

      if (!isClosed) emit(loaded);

      if (sections.isNotEmpty) {
        _loadAllSectionProducts(
            sections.map((s) => s.subCategory.id).toList());
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
          freshState.directProductsSkip + response.products.length <
              response.totalProducts,
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