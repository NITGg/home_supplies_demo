import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/products/manager/product_details_states.dart';

import '../../../core/utils/extract_error_message.dart';
import '../data/repo/product_repo.dart';


class ProductDetailCubit extends Cubit<ProductDetailState> {
  final ProductRepository _repository;

  ProductDetailCubit({ProductRepository? repository})
      : _repository = repository ?? ProductRepositoryImpl(),
        super(const ProductDetailInitial());

  Future<void> load(int productId) async {
    emit(const ProductDetailLoading());
    try {
      final product = await _repository.getProductById(productId);
      emit(ProductDetailLoaded(product));
    } catch (e) {
      emit(ProductDetailError(extractErrorMessage(e)));
    }
  }
}