import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/extract_error_message.dart';
import '../data/repositories/wallet_repo.dart';
import 'wallet_state.dart';

class WalletCubit extends Cubit<WalletState> {
  final WalletRepository repository;

  WalletCubit({required this.repository}) : super(WalletInitial());

  /// Returns the badge from the last successful wallet load, or null.
  /// The drawer header reads this to show the badge name under the avatar.
  dynamic get currentBadge {
    final s = state;
    if (s is WalletLoaded) return s.walletData.badge;
    return null;
  }

  Future<void> fetchWalletData() async {
    emit(WalletLoading());

    try {
      final walletData = await repository.getWalletData();
      emit(WalletLoaded(walletData: walletData));
    } catch (e) {
      emit(WalletError(message: extractErrorMessage(e)));
    }
  }

  Future<void> refreshWalletData() async {
    // Don't emit loading state for refresh to avoid UI flicker
    try {
      final walletData = await repository.getWalletData();
      emit(WalletLoaded(walletData: walletData));
    } catch (e) {
      emit(WalletError(message: extractErrorMessage(e)));
    }
  }
}