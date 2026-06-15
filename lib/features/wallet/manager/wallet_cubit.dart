// lib/features/wallet/manager/wallet_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../data/models/transaction_penality_models.dart';
import '../data/models/wallet_model.dart';
import '../data/repositories/wallet_repo.dart';
import '../../../core/utils/safe_emit_mixin.dart';
import 'wallet_state.dart';

class WalletCubit extends Cubit<WalletState> with SafeEmitMixin<WalletState> {
  final WalletRepository repository;

  // Caches
  List<WalletTransactionModel> _cachedTransactions = [];
  List<PenaltyModel> _cachedPenalties = [];
  PaginationModel? _transactionsPagination;
  PaginationModel? _penaltiesPagination;
  double _totalPenaltyAmount = 0.0;
  WalletModel? _cachedWalletData;



  WalletCubit({required this.repository}) : super(WalletInitial());

  WalletModel? get cachedWalletData => _cachedWalletData;

  dynamic get currentBadge {
    final s = state;
    if (s is WalletLoaded) return s.walletData.badge;
    return null;
  }
  double get totalPenaltyAmount => _totalPenaltyAmount;


  // ==================== Wallet ====================
  Future<void> fetchWalletData() async {
    safeEmit(WalletLoading());
    try {
      final walletData = await repository.getWalletData();
      _cachedWalletData = walletData;

      safeEmit(WalletLoaded(walletData: walletData));
    } catch (e) {
      safeEmit(WalletError(message: extractErrorMessage(e)));
    }
  }

  Future<void> refreshWalletData() async {
    try {
      final walletData = await repository.getWalletData();
      _cachedWalletData = walletData;
      safeEmit(WalletLoaded(walletData: walletData));
    } catch (e) {
      safeEmit(WalletError(message: extractErrorMessage(e)));
    }
  }

  // ==================== Transactions ====================
  Future<void> fetchTransactions({int page = 1, int limit = 20, String? startDate, String? endDate}) async {
    if (page == 1) {
      _cachedTransactions = [];
      _transactionsPagination = null;
      safeEmit(TransactionsLoading());
    } else if (_transactionsPagination != null) {
      safeEmit(TransactionsLoaded(
        transactions: _cachedTransactions,
        pagination: _transactionsPagination!,
        isLoadingMore: true,
      ));
    }

    try {
      final result = await repository.getTransactions(
        page: page,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );

      final newTransactions = result['transactions'] as List<WalletTransactionModel>;
      final pagination = result['pagination'] as PaginationModel;

      if (page == 1) {
        _cachedTransactions = newTransactions;
      } else {
        _cachedTransactions.addAll(newTransactions);
      }

      _transactionsPagination = pagination;

      safeEmit(TransactionsLoaded(
        transactions: _cachedTransactions,
        pagination: pagination,
        isLoadingMore: false,
      ));
    } catch (e) {
      safeEmit(TransactionsError(message: extractErrorMessage(e)));
    }
  }

  // ==================== Penalties ====================
  Future<void> fetchPenalties({int page = 1, int limit = 20}) async {
    if (page == 1) {
      _cachedPenalties = [];
      _penaltiesPagination = null;
      safeEmit(PenaltiesLoading());
    } else if (_penaltiesPagination != null) {
      safeEmit(PenaltiesLoaded(
        totalPenaltyAmount: 0,
        penalties: _cachedPenalties,
        pagination: _penaltiesPagination!,
        isLoadingMore: true,
      ));
    }

    try {
      final result = await repository.getPenalties(
        page: page,
        limit: limit,
      );

      final newPenalties = result['penalties'] as List<PenaltyModel>;
      final pagination = result['pagination'] as PaginationModel;
      final totalPenaltyAmount = result['totalPenaltyAmount'] as double;
      _totalPenaltyAmount = totalPenaltyAmount/100;

      if (page == 1) {
        _cachedPenalties = newPenalties;
      } else {
        _cachedPenalties.addAll(newPenalties);
      }

      _penaltiesPagination = pagination;

      safeEmit(PenaltiesLoaded(
        totalPenaltyAmount: totalPenaltyAmount,
        penalties: _cachedPenalties,
        pagination: pagination,
        isLoadingMore: false,
      ));
    } catch (e) {
      safeEmit(PenaltiesError(message: extractErrorMessage(e)));
    }
  }

  // ==================== Top-Up ====================
  Future<void> initiateOnlineTopUp({required int amount, String? provider}) async {
    dLog('💳 initiateOnlineTopUp: amount=$amount, provider=$provider');
    safeEmit(TopUpLoading());
    try {
      final response = await repository.initiateRecharge(amount, provider: provider);
      dLog('✅ initiateRecharge success: provider=${response.provider}, transactionId=${response.transactionId}, checkoutUrl=${response.checkoutUrl}');
      safeEmit(TopUpInitiated(response: response));
    } catch (e, st) {
      dLog('❌ initiateRecharge error: $e\n$st');
      safeEmit(TopUpError(message: extractErrorMessage(e)));
    }
  }
}