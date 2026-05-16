import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../../products/data/models/product_model.dart';
import '../../products/data/repo/product_repo.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class HomeProductsData extends Equatable {
  final List<ProductModel> offered;
  final List<ProductModel> bestSelling;
  final List<ProductModel> featured;
  final List<ProductModel> lastPurchased;

  const HomeProductsData({
    this.offered = const [],
    this.bestSelling = const [],
    this.featured = const [],
    this.lastPurchased = const [],
  });

  HomeProductsData copyWith({
    List<ProductModel>? offered,
    List<ProductModel>? bestSelling,
    List<ProductModel>? featured,
    List<ProductModel>? lastPurchased,
  }) =>
      HomeProductsData(
        offered: offered ?? this.offered,
        bestSelling: bestSelling ?? this.bestSelling,
        featured: featured ?? this.featured,
        lastPurchased: lastPurchased ?? this.lastPurchased,
      );

  @override
  List<Object?> get props => [offered, bestSelling, featured, lastPurchased];
}

sealed class HomeProductsState extends Equatable {
  const HomeProductsState();
  @override
  List<Object?> get props => [];
}

class HomeProductsLoading extends HomeProductsState {
  const HomeProductsLoading();
}

class HomeProductsLoaded extends HomeProductsState {
  final HomeProductsData data;
  const HomeProductsLoaded(this.data);
  @override
  List<Object?> get props => [data];
}

class HomeProductsError extends HomeProductsState {
  final String message;
  const HomeProductsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

/// Fetches all four home product sections in parallel with a single
/// [Future.wait] call so the page populates in one network round-trip
/// instead of four sequential waves.
///
/// Provide via [BlocProvider] above [CategoriesGridWidget] so it survives
/// navigation and the data is ready when the user returns to home.
class HomeProductsCubit extends Cubit<HomeProductsState> {
  final ProductRepository _repo;
  final bool isGuest;

  static const int _pageSize = 5;

  HomeProductsCubit({
    ProductRepository? repo,
    this.isGuest = false,
  })  : _repo = repo ?? ProductRepositoryImpl(),
  // ✅ Start in loading so no blank-state flash on first build.
        super(const HomeProductsLoading());

  /// Loads all sections in parallel. Safe to call on refresh.
  Future<void> load({bool refresh = false}) async {
    if (!refresh && state is HomeProductsLoaded) return;
    if (!isClosed) emit(const HomeProductsLoading());

    try {
      // ✅ All four requests fire simultaneously — total wait time equals the
      // slowest request, not the sum of all four.
      final futures = await Future.wait([
        _repo.getProducts(skip: 0, limit: _pageSize, isOffered: true),
        _repo.getProducts(skip: 0, limit: _pageSize, isBestSelling: true),
        _repo.getProducts(skip: 0, limit: _pageSize, isFeatured: true),
        if (!isGuest)
          _repo.getProducts(skip: 0, limit: _pageSize, isLastPurchased: true)
        else
          Future.value(null), // guest — skip last-purchased
      ]);

      if (isClosed) return;

      emit(HomeProductsLoaded(HomeProductsData(
        offered: futures[0]?.products ?? [],
        bestSelling: futures[1]?.products ?? [],
        featured: futures[2]?.products ?? [],
        lastPurchased: futures[3]?.products ?? [],
      )));
    } catch (e) {
      dLog('[HomeProductsCubit] load error: $e');
      if (!isClosed) emit(HomeProductsError(extractErrorMessage(e)));
    }
  }

  /// Appends the next page for a single section without re-fetching the others.
  Future<void> loadMoreOffered(int currentCount) =>
      _loadMore(currentCount, section: _Section.offered);
  Future<void> loadMoreBestSelling(int currentCount) =>
      _loadMore(currentCount, section: _Section.bestSelling);
  Future<void> loadMoreFeatured(int currentCount) =>
      _loadMore(currentCount, section: _Section.featured);
  Future<void> loadMoreLastPurchased(int currentCount) =>
      _loadMore(currentCount, section: _Section.lastPurchased);

  Future<void> _loadMore(int skip, {required _Section section}) async {
    final current = state;
    if (current is! HomeProductsLoaded) return;

    try {
      final response = await _repo.getProducts(
        skip: skip,
        limit: _pageSize,
        isOffered: section == _Section.offered ? true : null,
        isBestSelling: section == _Section.bestSelling ? true : null,
        isFeatured: section == _Section.featured ? true : null,
        isLastPurchased: section == _Section.lastPurchased ? true : null,
      );

      if (isClosed) return;

      final data = current.data;
      emit(HomeProductsLoaded(switch (section) {
        _Section.offered =>
            data.copyWith(offered: [...data.offered, ...response.products]),
        _Section.bestSelling => data.copyWith(
            bestSelling: [...data.bestSelling, ...response.products]),
        _Section.featured =>
            data.copyWith(featured: [...data.featured, ...response.products]),
        _Section.lastPurchased => data.copyWith(
            lastPurchased: [...data.lastPurchased, ...response.products]),
      }));
    } catch (e) {
      dLog('[HomeProductsCubit] loadMore error: $e');
    }
  }
}

enum _Section { offered, bestSelling, featured, lastPurchased }