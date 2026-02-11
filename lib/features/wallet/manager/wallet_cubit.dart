import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories/wallet_repo.dart';
import 'wallet_state.dart';

class WalletCubit extends Cubit<WalletState> {
  final WalletRepository repository;

  WalletCubit({required this.repository}) : super(WalletInitial());

  Future<void> fetchWalletData() async {
    emit(WalletLoading());

    try {
      final walletData = await repository.getWalletData();
      emit(WalletLoaded(walletData: walletData));
    } catch (e) {
      emit(WalletError(message: e.toString()));
    }
  }

  Future<void> refreshWalletData() async {
    // Don't emit loading state for refresh to avoid UI flicker
    try {
      final walletData = await repository.getWalletData();
      emit(WalletLoaded(walletData: walletData));
    } catch (e) {
      emit(WalletError(message: e.toString()));
    }
  }
}