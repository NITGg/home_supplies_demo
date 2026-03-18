// lib/features/wallet/manager/wallet_state.dart

import '../data/models/transaction_penality_models.dart';
import '../data/models/wallet_model.dart';
import '../data/models/recharge_model.dart';

abstract class WalletState {}

// ==================== Initial & Loading States ====================
class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class TransactionsLoading extends WalletState {}

class PenaltiesLoading extends WalletState {}

class TopUpLoading extends WalletState {}

// ==================== Success States ====================
class WalletLoaded extends WalletState {
  final WalletModel walletData;

  WalletLoaded({required this.walletData});
}

class TransactionsLoaded extends WalletState {
  final List<WalletTransactionModel> transactions;
  final PaginationModel pagination;
  final bool isLoadingMore;

  TransactionsLoaded({
    required this.transactions,
    required this.pagination,
    this.isLoadingMore = false,
  });
}

class PenaltiesLoaded extends WalletState {
  final List<PenaltyModel> penalties;
  final PaginationModel pagination;
  final double totalPenaltyAmount;
  final bool isLoadingMore;

  PenaltiesLoaded({
    required this.penalties,
    required this.totalPenaltyAmount,
    required this.pagination,
    this.isLoadingMore = false,
  });
}

class TopUpInitiated extends WalletState {
  final RechargeModel response;

  TopUpInitiated({required this.response});
}

// ==================== Error States ====================
class WalletError extends WalletState {
  final String message;

  WalletError({required this.message});
}

class TransactionsError extends WalletState {
  final String message;

  TransactionsError({required this.message});
}

class PenaltiesError extends WalletState {
  final String message;

  PenaltiesError({required this.message});
}

class TopUpError extends WalletState {
  final String message;

  TopUpError({required this.message});
}