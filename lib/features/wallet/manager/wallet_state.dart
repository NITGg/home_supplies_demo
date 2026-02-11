
import '../data/models/wallet_model.dart';

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