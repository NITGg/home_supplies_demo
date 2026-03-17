import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  static const int ordersTabIndex = 0;

  int currentIndex = 0;

  HomeCubit() : super(HomeInitial());

  void changeTab(int index) {
    if (index == currentIndex) return;
    currentIndex = index;
    emit(HomeTabChanged(index));
  }

  void requestHistoryTab() {
    // If we're not on the orders tab, go there first
    currentIndex = ordersTabIndex;
    // Emit the intent — OrdersListScreen's BlocListener catches this
    emit(HomeHistoryTabRequested());
  }
}