import 'package:equatable/equatable.dart';
import '../data/models/cart_response_model.dart';
import '../data/models/order_preview_model.dart';

sealed class CartState extends Equatable {
  const CartState();

  @override
  List<Object?> get props => [];
}

class CartInitial extends CartState {
  const CartInitial();
}

class CartLoading extends CartState {
  const CartLoading();
}



class CartLoaded extends CartState {
  final CartResponseModel data;
  final Set<int> busyItemIds;
  final OrderPreviewModel? preview; // ← new

  const CartLoaded(this.data, {this.busyItemIds = const {}, this.preview});

  bool isItemBusy(int id) => busyItemIds.contains(id);

  CartLoaded copyWith({
    CartResponseModel? data,
    Set<int>? busyItemIds,
    OrderPreviewModel? preview,
    bool clearPreview = false, // ← needed to explicitly null it out
  }) {
    return CartLoaded(
      data ?? this.data,
      busyItemIds: busyItemIds ?? this.busyItemIds,
      preview: clearPreview ? null : preview ?? this.preview,
    );
  }

  @override
  List<Object?> get props => [data, busyItemIds, preview];
}

class CartError extends CartState {
  final String message;

  const CartError(this.message);

  @override
  List<Object?> get props => [message];
}