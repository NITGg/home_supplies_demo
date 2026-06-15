import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/safe_emit_mixin.dart';

/// Holds a single boolean — whether the current session is a guest.
///
/// Provided at [HomeLayout] level so any descendant widget can read or
/// react to guest-mode changes without prop-drilling.
class GuestModeCubit extends Cubit<bool> with SafeEmitMixin<bool> {
  GuestModeCubit() : super(false);

  void setGuest(bool isGuest) {
    if (state != isGuest) safeEmit(isGuest);
  }
}