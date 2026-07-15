import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeState extends Equatable {
  final int currentIndex;
  const HomeState({this.currentIndex = 0});
  HomeState copyWith({int? currentIndex}) =>
      HomeState(currentIndex: currentIndex ?? this.currentIndex);

  @override
  List<Object?> get props => [currentIndex];
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(const HomeState());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed.
  @override
  void emit(HomeState state) {
    if (!isClosed) super.emit(state);
  }

  int get currentIndex => state.currentIndex;

  bool pendingHistoryTab = false; // 👈 add this

  final StreamController<void> _historyTabController =
  StreamController<void>.broadcast();

  Stream<void> get onHistoryTabRequested => _historyTabController.stream;

  void changeTab(int index) => emit(state.copyWith(currentIndex: index));

  Future<void> requestHistoryTab() async {
    changeTab(1);
    pendingHistoryTab = true; // 👈 set before the delay

    await Future.delayed(const Duration(milliseconds: 300));

    if (!_historyTabController.isClosed) {
      pendingHistoryTab = false; // 👈 clear when actually emitting
      _historyTabController.add(null);
    }
  }

  void consumePendingHistoryTab() {
    pendingHistoryTab = false; // 👈 called by the screen on cold-start
  }

  @override
  Future<void> close() {
    _historyTabController.close();
    return super.close();
  }
}