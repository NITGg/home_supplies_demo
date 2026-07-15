import 'package:equatable/equatable.dart';
import '../data/models/recharge_model.dart';
import '../data/models/wallet_models.dart';

abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

// ==================== Initial State ====================
class WalletInitial extends WalletState {
  const WalletInitial();
}

// ==================== Loading States ====================
class WalletLoading extends WalletState {
  const WalletLoading();
}

class TransactionsLoading extends WalletState {
  const TransactionsLoading();
}

class PenaltiesLoading extends WalletState {
  const PenaltiesLoading();
}

class UnpaidCommissionsLoading extends WalletState {
  const UnpaidCommissionsLoading();
}

class TopUpProcessing extends WalletState {
  const TopUpProcessing();
}

// ==================== Success States ====================
class WalletLoaded extends WalletState {
  final WalletModel wallet;
  final double totalUnpaidCommission;
  final double totalPendingPenalties;

  const WalletLoaded({
    required this.wallet,
    required this.totalUnpaidCommission,
    required this.totalPendingPenalties,
  });

  double get availableBalance =>
      wallet.balance - totalUnpaidCommission - totalPendingPenalties;

  @override
  List<Object?> get props => [wallet, totalUnpaidCommission, totalPendingPenalties];
}

class TransactionsLoaded extends WalletState {
  final List<WalletTransactionModel> transactions;
  final PaginationModel pagination;
  final bool isLoadingMore;

  const TransactionsLoaded({
    required this.transactions,
    required this.pagination,
    this.isLoadingMore = false,
  });

  @override
  List<Object?> get props => [transactions, pagination, isLoadingMore];
}

/// Penalties now use [SkipLimitPaginationModel] because the API switched from
/// page-based to skip/limit pagination.
class PenaltiesLoaded extends WalletState {
  final List<PenaltyModel> penalties;
  final SkipLimitPaginationModel pagination;
  final bool isLoadingMore;

  const PenaltiesLoaded({
    required this.penalties,
    required this.pagination,
    this.isLoadingMore = false,
  });

  @override
  List<Object?> get props => [penalties, pagination, isLoadingMore];
}

/// Unpaid commissions also use [SkipLimitPaginationModel].
class UnpaidCommissionsLoaded extends WalletState {
  final List<UnpaidCommissionModel> commissions;
  final SkipLimitPaginationModel pagination;
  final bool isLoadingMore;

  const UnpaidCommissionsLoaded({
    required this.commissions,
    required this.pagination,
    this.isLoadingMore = false,
  });

  @override
  List<Object?> get props => [commissions, pagination, isLoadingMore];
}

class TopUpInitiated extends WalletState {
  final RechargeModel response;

  const TopUpInitiated({required this.response});

  @override
  List<Object?> get props => [response];
}

// ==================== Error States ====================
class WalletError extends WalletState {
  final String message;

  const WalletError({required this.message});

  @override
  List<Object?> get props => [message];
}

class TransactionsError extends WalletState {
  final String message;

  const TransactionsError({required this.message});

  @override
  List<Object?> get props => [message];
}

class PenaltiesError extends WalletState {
  final String message;

  const PenaltiesError({required this.message});

  @override
  List<Object?> get props => [message];
}

class UnpaidCommissionsError extends WalletState {
  final String message;

  const UnpaidCommissionsError({required this.message});

  @override
  List<Object?> get props => [message];
}

class TopUpError extends WalletState {
  final String message;

  const TopUpError({required this.message});

  @override
  List<Object?> get props => [message];
}
