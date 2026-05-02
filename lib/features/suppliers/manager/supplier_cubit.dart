import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/extract_error_message.dart';
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
class SuppliersCubit extends Cubit<SuppliersState> {
  final SupplierRepository _repository;

  /// The category ids used to filter suppliers.  Empty means "no filter".
  final List<int> categoryIds;

  SuppliersCubit({
    SupplierRepository? repository,
    this.categoryIds = const [],
  })  : _repository = repository ?? SupplierRepositoryImpl(),
        super(const SuppliersInitial());

  Future<void> loadSuppliers({bool refresh = false}) async {
    if (!refresh && state is SuppliersLoading) return;
    if (!isClosed) emit(const SuppliersLoading());

    try {
      final suppliers = await _fetchAndMerge();
      if (!isClosed) emit(SuppliersLoaded(suppliers: suppliers));
    } catch (e) {
      log('SuppliersCubit: Error loading suppliers: $e');
      if (!isClosed) emit(SuppliersError(extractErrorMessage(e)));
    }
  }

  /// Fetches suppliers for every id in [categoryIds] in parallel and returns
  /// a deduplicated list ordered by first occurrence.
  ///
  /// When [categoryIds] is empty a single unfiltered request is made.
  Future<List<SupplierModel>> _fetchAndMerge() async {
    if (categoryIds.isEmpty) {
      final response = await _repository.getSuppliers();
      return response.suppliers;
    }

    if (categoryIds.length == 1) {
      final response =
      await _repository.getSuppliers(categoryId: categoryIds.first);
      return response.suppliers;
    }

    // Fan out — one request per category id, all in parallel.
    final responses = await Future.wait(
      categoryIds.map((id) => _repository.getSuppliers(categoryId: id)),
    );

    // Merge and deduplicate, preserving first-seen order.
    final seen = <int>{};
    final merged = <SupplierModel>[];
    for (final response in responses) {
      for (final supplier in response.suppliers) {
        if (seen.add(supplier.id)) {
          merged.add(supplier);
        }
      }
    }
    return merged;
  }
}