import '../data/models/order_model.dart';

abstract class OrderState {
  const OrderState();

  @override
  List<Object?> get props => [];
}

class OrderInitial extends OrderState {}

class OrderLoading extends OrderState {}

class OrderSuccess extends OrderState {
  final String message;
  final Order order;

  const OrderSuccess({
    required this.message,
    required this.order,
  });

  @override
  List<Object?> get props => [message, order];
}

class OrderError extends OrderState {
  final String message;

  const OrderError(this.message);

  @override
  List<Object?> get props => [message];
}