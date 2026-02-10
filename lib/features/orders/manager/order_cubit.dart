import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/order_model.dart';
import '../data/repositories/order_repo.dart';
import 'order_states.dart';

class OrderCubit extends Cubit<OrderState> {
  final OrderRepository _repository;

  OrderCubit({
    OrderRepository? repository,
  })  : _repository = repository ?? OrderRepository(),
        super(OrderInitial());

  Future<void> createOrder(Order order) async {
    emit(OrderLoading());
    try {
      log('OrderCubit: Creating order');
      final response = await _repository.createOrder(order);
      log('OrderCubit: Order created successfully - ${response.order.orderNumber}');

      emit(OrderSuccess(
        message: response.message,
        order: response.order,
      ));
    } catch (e) {
      log('OrderCubit: Error creating order: $e');
      emit(OrderError(e.toString()));
    }
  }

  void reset() {
    emit(OrderInitial());
  }
}