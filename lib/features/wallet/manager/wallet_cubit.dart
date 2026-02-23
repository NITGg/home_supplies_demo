// lib/features/wallet/manager/wallet_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/extract_error_message.dart';
import '../data/repositories/wallet_repo.dart';
import 'wallet_state.dart';

class WalletCubit extends Cubit<WalletState> {
  final WalletRepository repository;

  WalletCubit({required this.repository}) : super(WalletInitial());

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
    try {
      final walletData = await repository.getWalletData();
      emit(WalletLoaded(walletData: walletData));
    } catch (e) {
      emit(WalletError(message: extractErrorMessage(e)));
    }
  }

  Future<void> initiateOnlineTopUp({required int amount}) async {
    emit(TopUpLoading());
    try {
      final response = await repository.initiateRecharge(amount);
      emit(TopUpInitiated(response: response));
    } catch (e) {
      emit(TopUpError(message: extractErrorMessage(e)));
    }
  }
}