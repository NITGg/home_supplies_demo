import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories/orders_repo.dart';
import 'orders_states.dart';

class OrderCubit extends Cubit<OrderState> {
  final OrderRepository _repository;

  OrderCubit(this._repository) : super(AvailableOrdersInitial());

  // ============== Available Orders ==============
  Future<void> fetchAvailableOrders({int page = 1, int limit = 20}) async {
    emit(AvailableOrdersLoading());
    try {
      final result = await _repository.getAvailableOrders(
        page: page,
        limit: limit,
      );
      emit(
        AvailableOrdersLoaded(
          orders: result['orders'],
          pagination: result['pagination'],
        ),
      );
    } catch (e) {
      emit(AvailableOrdersError(_getErrorMessage(e)));
    }
  }

  // ============== Order Details ==============
  Future<void> fetchOrderDetails(
    int orderId, {
    bool fetchFeeRange = false,
  }) async {
    emit(OrderDetailsLoading());
    try {
      final order = await _repository.getOrderDetails(orderId);

      if (fetchFeeRange) {
        final feeRange = await _repository.getAllowedFeeRange(orderId);
        emit(OrderDetailsLoaded(order: order, feeRange: feeRange));
      } else {
        emit(OrderDetailsLoaded(order: order));
      }
    } catch (e) {
      emit(OrderDetailsError(_getErrorMessage(e)));
    }
  }

  // ============== Submit Offer ==============
  Future<void> submitOffer({
    required int orderId,
    required double totalFee,
  }) async {
    emit(SubmittingOffer());
    try {
      final proposal = await _repository.submitOffer(
        orderId: orderId,
        totalFee: totalFee,
      );
      emit(OfferSubmitted(proposal));
    } catch (e) {
      emit(OfferSubmitError(_getErrorMessage(e)));
    }
  }

  // ============== Active Order ==============
  Future<void> fetchActiveOrder() async {
    emit(ActiveOrderLoading());
    try {
      final order = await _repository.getActiveOrder();
      if (order == null) {
        emit(NoActiveOrder());
      } else {
        emit(ActiveOrderLoaded(order));
      }
    } catch (e) {
      emit(ActiveOrderError(_getErrorMessage(e)));
    }
  }

  // ============== Complete Delivery ==============
  Future<void> completeDelivery({
    required int orderId,
    required double actualPrice,
  }) async {
    emit(CompletingDelivery());
    try {
      final qrCode = await _repository.completeDelivery(
        orderId: orderId,
        actualPrice: actualPrice,
      );
      emit(DeliveryCompleted(qrCode));
    } catch (e) {
      emit(DeliveryCompleteError(_getErrorMessage(e)));
    }
  }

  Future<bool> hasActiveOrder() async {
    try {
      final order = await _repository.getActiveOrder();
      return order != null;
    } catch (e) {
      return false;
    }
  }

  // Helper method to extract error messages
  String _getErrorMessage(dynamic error) {
    return error.toString().replaceAll('Exception:', '').trim();
  }
}
