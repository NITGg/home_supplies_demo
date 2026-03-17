part of 'home_cubit.dart';

abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeTabChanged extends HomeState {
  final int index;

  HomeTabChanged(this.index);
}
class HomeHistoryTabRequested extends HomeState {}
