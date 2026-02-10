import '../data/models/governorate_model.dart';

abstract class GovernorateState {
  const GovernorateState();

  @override
  List<Object?> get props => [];
}

class GovernorateInitial extends GovernorateState {}

class GovernorateLoading extends GovernorateState {}

class GovernoratesLoaded extends GovernorateState {
  final GovernoratesResponse response;

  const GovernoratesLoaded(this.response);

  @override
  List<Object?> get props => [response];
}

class GovernorateError extends GovernorateState {
  final String message;

  const GovernorateError(this.message);

  @override
  List<Object?> get props => [message];
}