import 'package:equatable/equatable.dart';
import '../../suppliers/data/models/supplier_models.dart';
import '../data/models/product_model.dart';

sealed class ProductDetailState extends Equatable {
  const ProductDetailState();

  @override
  List<Object?> get props => [];
}

class ProductDetailInitial extends ProductDetailState {
  const ProductDetailInitial();
}

class ProductDetailLoading extends ProductDetailState {
  const ProductDetailLoading();
}

class ProductDetailLoaded extends ProductDetailState {
  final ProductModel product;

  /// Whether the supplier that owns this product is currently open.
  /// Defaults to true so that screens without supplier context are unaffected.
  final bool isSupplierOpen;

  /// Full supplier info fetched alongside the product. May be null if the
  /// product has no supplier context or the fetch failed.
  final SupplierModel? supplier;

  const ProductDetailLoaded(
    this.product, {
    this.isSupplierOpen = true,
    this.supplier,
  });

  @override
  List<Object?> get props => [product, isSupplierOpen, supplier];
}

class ProductDetailError extends ProductDetailState {
  final String message;

  const ProductDetailError(this.message);

  @override
  List<Object?> get props => [message];
}