part of 'home_cubit.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeTabChanged extends HomeState {
  final int index;

  const HomeTabChanged(this.index);

  @override
  List<Object?> get props => [index];
}

class HomeHistoryTabRequested extends HomeState {}
