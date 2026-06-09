import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/products/manager/product_details_states.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../suppliers/data/models/supplier_models.dart';
import '../../suppliers/data/repo/supplier_repo.dart';
import '../data/repo/product_repo.dart';

class ProductDetailCubit extends Cubit<ProductDetailState> {
  final ProductRepository _repository;
  final SupplierRepository _supplierRepository;

  ProductDetailCubit({ProductRepository? repository, SupplierRepository? supplierRepository})
      : _repository = repository ?? ProductRepositoryImpl(),
        _supplierRepository = supplierRepository ?? SupplierRepositoryImpl(),
        super(const ProductDetailInitial());

  Future<void> load(int productId, {int? supplierId}) async {
    if (!isClosed) {
      emit(const ProductDetailLoading());
    }
    try {
      final product = await _repository.getProductById(
        productId,
        supplierId: supplierId,
      );

      // Check whether the supplier is currently open.
      bool isSupplierOpen = true;
      final sid = product.supplierId ?? supplierId;
      SupplierModel? supplier;
      if (sid != null) {
        try {
          supplier = await _supplierRepository.getSupplierById(sid);
          isSupplierOpen = supplier.currentStatus?.isOpen ?? true;
        } catch (_) {
          // If supplier fetch fails, default to open so we never block the user
          // on a network error.
          isSupplierOpen = true;
        }
      }

      if (!isClosed) {
        emit(ProductDetailLoaded(
          product,
          isSupplierOpen: isSupplierOpen,
          supplier: supplier,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(ProductDetailError(extractErrorMessage(e)));
      }
    }
  }
}