
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../data/models/supplier_models.dart';
import '../data/repo/supplier_repo.dart';
import 'supplier_states.dart';

/// Manages the flat list of suppliers shown in the horizontal strip.
///
/// Pass [categoryIds] to restrict results to suppliers that serve any of those
/// categories. When the list contains more than one id (e.g. all sub-category
/// ids belonging to a parent category) the cubit fans out the requests in
/// parallel and deduplicates the merged result by supplier id.
///
/// Leave [categoryIds] empty (or omit it) to fetch all suppliers.
///
/// All suppliers are shown equally — there is no platform-level exclusion.
class SuppliersCubit extends Cubit<SuppliersState> {
  final SupplierRepository _repository;

  /// The category ids used to filter suppliers.  Empty means "no filter".
  final List<int> categoryIds;

  static const int _pageSize = 20;

  SuppliersCubit({
    SupplierRepository? repository,
    this.categoryIds = const [],
  })  : _repository = repository ?? SupplierRepositoryImpl(),
        super(const SuppliersInitial());

  Future<void> loadSuppliers({bool refresh = false}) async {
    if (!refresh && state is SuppliersLoading) return;
    if (!isClosed) emit(const SuppliersLoading());

    try {
      final result = await _fetchPage(skip: 0);
      if (!isClosed) {
        emit(SuppliersLoaded(
          suppliers: result.suppliers,
          skip: result.suppliers.length,
          hasMore: result.hasMore,
        ));
      }
    } catch (e) {
      dLog('SuppliersCubit: Error loading suppliers: $e');
      if (!isClosed) emit(SuppliersError(extractErrorMessage(e)));
    }
  }

  /// Fetches the next page and appends it to the currently loaded suppliers.
  Future<void> loadMore() async {
    final current = state;
    if (current is! SuppliersLoaded) return;
    if (!current.hasMore || current.isLoadingMore) return;

    if (!isClosed) emit(current.copyWith(isLoadingMore: true));

    try {
      final result = await _fetchPage(skip: current.skip);

      if (isClosed) return;

      // Deduplicate against what's already loaded (defensive — backends can
      // return overlapping results if items shift between pages).
      final seen = current.suppliers.map((s) => s.id).toSet();
      final merged = [
        ...current.suppliers,
        ...result.suppliers.where((s) => seen.add(s.id)),
      ];

      emit(current.copyWith(
        suppliers: merged,
        skip: current.skip + result.suppliers.length,
        hasMore: result.hasMore,
        isLoadingMore: false,
      ));
    } catch (e) {
      dLog('SuppliersCubit: Error loading more suppliers: $e');
      if (!isClosed) emit(current.copyWith(isLoadingMore: false));
    }
  }

  /// Fetches one page of suppliers starting at [skip].
  ///
  /// When [categoryIds] has more than one entry, requests are fanned out in
  /// parallel (one per category id) and merged/deduplicated — pagination
  /// across multiple fanned-out sources isn't well-defined, so in that case
  /// a single larger page is fetched and `hasMore` is reported as `false`.
  Future<_SuppliersPage> _fetchPage({required int skip}) async {
    if (categoryIds.isEmpty) {
      final response =
          await _repository.getSuppliers(skip: skip, limit: _pageSize);
      return _SuppliersPage(
        suppliers: response.suppliers,
        hasMore: skip + response.suppliers.length < response.totalSuppliers,
      );
    }

    if (categoryIds.length == 1) {
      final response = await _repository.getSuppliers(
        categoryId: categoryIds.first,
        skip: skip,
        limit: _pageSize,
      );
      return _SuppliersPage(
        suppliers: response.suppliers,
        hasMore: skip + response.suppliers.length < response.totalSuppliers,
      );
    }

    // Fan out — one request per category id, all in parallel. Pagination
    // isn't supported in this branch; fetch a single generous page.
    final responses = await Future.wait(
      categoryIds.map(
        (id) => _repository.getSuppliers(categoryId: id, skip: 0, limit: 100),
      ),
    );

    final seen = <int>{};
    final raw = <SupplierModel>[];
    for (final response in responses) {
      for (final supplier in response.suppliers) {
        if (seen.add(supplier.id)) {
          raw.add(supplier);
        }
      }
    }

    dLog('SuppliersCubit: after dedup=${raw.length}');
    return _SuppliersPage(suppliers: raw, hasMore: false);
  }
}

class _SuppliersPage {
  final List<SupplierModel> suppliers;
  final bool hasMore;

  const _SuppliersPage({required this.suppliers, required this.hasMore});
}
