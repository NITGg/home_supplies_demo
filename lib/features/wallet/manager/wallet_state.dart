// lib/features/wallet/manager/wallet_state.dart

import '../data/models/wallet_model.dart';
import '../data/models/recharge_model.dart';

abstract class WalletState {}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final WalletModel walletData;
  WalletLoaded({required this.walletData});
}

class WalletError extends WalletState {
  final String message;
  WalletError({required this.message});
}

// TopUp states
class TopUpLoading extends WalletState {}

class TopUpInitiated extends WalletState {
  final RechargeModel response;
  TopUpInitiated({required this.response});
}

class TopUpError extends WalletState {
  final String message;
  TopUpError({required this.message});
}