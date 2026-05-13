import 'package:flutter_bloc/flutter_bloc.dart';

/// Holds a single boolean — whether the current session is a guest.
///
/// Provided at [HomeLayout] level so any descendant widget can read or
/// react to guest-mode changes without prop-drilling.
class GuestModeCubit extends Cubit<bool> {
  GuestModeCubit() : super(false);

  void setGuest(bool isGuest) {
    if (state != isGuest) emit(isGuest);
  }
}