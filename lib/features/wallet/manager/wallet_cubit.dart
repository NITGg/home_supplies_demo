import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../data/models/wallet_models.dart';
import '../data/repositories/wallet_repo.dart';
import 'wallet_states.dart';

class WalletCubit extends Cubit<WalletState> {
  final WalletRepository _repository = WalletRepository();

  // Cache data
  WalletModel? _cachedWallet;
  List<WalletTransactionModel> _cachedTransactions = [];
  List<PenaltyModel> _cachedPenalties = [];
  List<UnpaidCommissionModel> _cachedCommissions = [];

  // Pagination cache – transactions remain page-based
  PaginationModel? _transactionsPagination;

  // Penalties & commissions use skip/limit pagination
  SkipLimitPaginationModel? _penaltiesPagination;
  SkipLimitPaginationModel? _commissionsPagination;

  String? _transactionsStartDate;
  String? _transactionsEndDate;

  WalletCubit() : super(const WalletInitial());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed.
  @override
  void emit(WalletState state) {
    if (!isClosed) super.emit(state);
  }

  // ==================== Load Wallet Data ====================
  Future<void> loadWalletData() async {
    emit(const WalletLoading());

    try {
      final results = await Future.wait([
        _repository.getWalletData(),
        _repository.getTotalUnpaidCommission(),
        _repository.getTotalPendingPenalties(),
      ]);

      final wallet = results[0] as WalletModel;
      final totalUnpaid = results[1] as double;
      final totalPenalties = results[2] as double;

      _cachedWallet = wallet;
      if (!isClosed) {
        emit(
          WalletLoaded(
            wallet: wallet,
            totalUnpaidCommission: totalUnpaid,
            totalPendingPenalties: totalPenalties,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(WalletError(message: extractErrorMessage(e)));
      }
    }
  }

  // ==================== Load Transactions (page-based – unchanged) ====================
  Future<void> loadTransactions({
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    if (page == 1) {
      _transactionsStartDate = startDate;
      _transactionsEndDate = endDate;
      if (!isClosed) emit(TransactionsLoading());
      _cachedTransactions = [];
      _transactionsPagination = null;
    } else {
      // Use cached dates for load-more
      startDate = _transactionsStartDate;
      endDate = _transactionsEndDate;
      if (_transactionsPagination != null) {
        if (!isClosed) {
          emit(
            TransactionsLoaded(
              transactions: _cachedTransactions,
              pagination: _transactionsPagination!,
              isLoadingMore: true,
            ),
          );
        }
      }
    }

    try {
      final result = await _repository.getTransactions(
        page: page,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );

      final newTransactions =
      result['transactions'] as List<WalletTransactionModel>;
      final pagination = result['pagination'] as PaginationModel;

      if (page == 1) {
        _cachedTransactions = newTransactions;
      } else {
        _cachedTransactions.addAll(newTransactions);
      }

      _transactionsPagination = pagination;
      if (!isClosed) {
        emit(
          TransactionsLoaded(
            transactions: _cachedTransactions,
            pagination: pagination,
            isLoadingMore: false,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(TransactionsError(message: extractErrorMessage(e)));
      }
    }
  }

  // ==================== Load Penalties (skip/limit) ====================
  Future<void> loadPenalties({int skip = 0, int limit = 20}) async {
    if (skip == 0) {
      if (!isClosed) emit(PenaltiesLoading());
      _cachedPenalties = [];
      _penaltiesPagination = null;
    } else {
      // Load more – show spinner with current data
      if (_penaltiesPagination != null && !isClosed) {
        emit(
          PenaltiesLoaded(
            penalties: _cachedPenalties,
            pagination: _penaltiesPagination!,
            isLoadingMore: true,
          ),
        );
      }
    }

    try {
      final result =
      await _repository.getPenalties(skip: skip, limit: limit);
      final newPenalties = result['penalties'] as List<PenaltyModel>;
      final pagination = result['pagination'] as SkipLimitPaginationModel;

      if (skip == 0) {
        _cachedPenalties = newPenalties;
      } else {
        _cachedPenalties.addAll(newPenalties);
      }

      _penaltiesPagination = pagination;

      if (!isClosed) {
        emit(
          PenaltiesLoaded(
            penalties: _cachedPenalties,
            pagination: pagination,
            isLoadingMore: false,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(PenaltiesError(message: extractErrorMessage(e)));
      }
    }
  }

  // ==================== Load Unpaid Commissions (skip/limit) ====================
  Future<void> loadUnpaidCommissions({int skip = 0, int limit = 20}) async {
    if (skip == 0) {
      if (!isClosed) emit(UnpaidCommissionsLoading());
      _cachedCommissions = [];
      _commissionsPagination = null;
    } else {
      // Load more – show spinner with current data
      if (_commissionsPagination != null && !isClosed) {
        emit(
          UnpaidCommissionsLoaded(
            commissions: _cachedCommissions,
            pagination: _commissionsPagination!,
            isLoadingMore: true,
          ),
        );
      }
    }

    try {
      final result =
      await _repository.getUnpaidCommissions(skip: skip, limit: limit);
      final newCommissions =
      result['commissions'] as List<UnpaidCommissionModel>;
      final pagination = result['pagination'] as SkipLimitPaginationModel;

      if (skip == 0) {
        _cachedCommissions = newCommissions;
      } else {
        _cachedCommissions.addAll(newCommissions);
      }

      _commissionsPagination = pagination;
      if (!isClosed) {
        emit(
          UnpaidCommissionsLoaded(
            commissions: _cachedCommissions,
            pagination: pagination,
            isLoadingMore: false,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(UnpaidCommissionsError(message: extractErrorMessage(e)));
      }
    }
  }

  // ==================== Initiate TopUp (Online Payment) ====================
  Future<void> initiateOnlineTopUp({required int amount, String? provider}) async {
    dLog('💳 initiateOnlineTopUp: amount=$amount, provider=$provider');
    emit(TopUpProcessing());
    try {
      final response = await _repository.initiateRecharge(amount, provider: provider);
      dLog('✅ initiateRecharge success: provider=${response.provider}, transactionId=${response.transactionId}, checkoutUrl=${response.checkoutUrl}');
      emit(TopUpInitiated(response: response));
    } catch (e, st) {
      dLog('❌ initiateRecharge error: $e\n$st');
      emit(TopUpError(message: extractErrorMessage(e)));
    }
  }

  // ==================== Refresh All Data ====================
  Future<void> refreshAll() async {
    await loadWalletData();
  }

  // ==================== Get Cached Wallet ====================
  WalletModel? get cachedWallet => _cachedWallet;
}