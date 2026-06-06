import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  static const int ordersTabIndex = 1;

  int currentIndex = 0;
  bool pendingHistoryTab = false; // 👈 persists across missed emissions

  HomeCubit() : super(HomeInitial());

  void changeTab(int index) {
    if (index == currentIndex) return;
    currentIndex = index;
    emit(HomeTabChanged(index));
  }

  void requestHistoryTab() {
    currentIndex = ordersTabIndex;
    pendingHistoryTab = true;
    emit(HomeHistoryTabRequested());
  }

  void consumePendingHistoryTab() {
    pendingHistoryTab = false;
  }

  bool pendingActiveTab = false;

  void requestActiveTab() {
    currentIndex = ordersTabIndex;
    pendingActiveTab = true;
    emit(HomeActiveTabRequested());
  }

  void consumePendingActiveTab() {
    pendingActiveTab = false;
  }
}

class GoToTab {
  final int index;

  const GoToTab(this.index);
}
