import 'package:flutter_bloc/flutter_bloc.dart';
part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {

  int currentIndex = 0;

  HomeCubit() : super(HomeInitial());


  void changeTab(int index) {
    if (index == currentIndex) return;
    currentIndex = index;
    emit(HomeTabChanged(index));
  }
}
