import 'package:equatable/equatable.dart';
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

  const ProductDetailLoaded(this.product, {this.isSupplierOpen = true});

  @override
  List<Object?> get props => [product, isSupplierOpen];
}

class ProductDetailError extends ProductDetailState {
  final String message;

  const ProductDetailError(this.message);

  @override
  List<Object?> get props => [message];
}