import 'package:flutter_bloc/flutter_bloc.dart';

/// Adds [safeEmit], which emits a new state only if the cubit/bloc has not
/// been closed yet, preventing "emit after close" errors from late
/// async callbacks.
mixin SafeEmitMixin<State> on BlocBase<State> {
  void safeEmit(State state) {
    if (!isClosed) emit(state);
  }
}
