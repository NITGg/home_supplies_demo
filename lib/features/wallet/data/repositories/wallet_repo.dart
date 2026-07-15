import '../data_source/wallet_remote_data_source.dart';
import '../models/recharge_model.dart';
import '../models/wallet_models.dart';


class WalletRepository {
  final WalletDataSource _dataSource = WalletDataSource();

  // ==================== Get Wallet Data ====================
  Future<WalletModel> getWalletData() async {
    return await _dataSource.getWalletData();
  }

  // ==================== Get Transactions (page-based – unchanged) ====================
  Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    return await _dataSource.getTransactions(
      page: page,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // ==================== Get Penalties (skip/limit) ====================
  Future<Map<String, dynamic>> getPenalties({
    int skip = 0,
    int limit = 20,
  }) async {
    return await _dataSource.getPenalties(skip: skip, limit: limit);
  }

  // ==================== Get Unpaid Commissions (skip/limit) ====================
  Future<Map<String, dynamic>> getUnpaidCommissions({
    int skip = 0,
    int limit = 20,
  }) async {
    return await _dataSource.getUnpaidCommissions(skip: skip, limit: limit);
  }

  // ==================== Initiate TopUp ====================
  Future<RechargeModel> initiateRecharge(int amountCents, {String? provider}) async {
    return await _dataSource.initiateRecharge(amountCents, provider: provider);
  }

  // ==================== Calculate Total Unpaid Commission ====================
  Future<double> getTotalUnpaidCommission() async {
    try {
      final result = await getUnpaidCommissions(limit: 100);
      final commissions = result['commissions'] as List<UnpaidCommissionModel>;

      double total = 0.0;
      for (var commission in commissions) {
        if (!commission.isPaid) {
          total += commission.amount;
        }
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  // ==================== Calculate Total Pending Penalties ====================
  Future<double> getTotalPendingPenalties() async {
    try {
      final result = await getPenalties(limit: 100);
      final penalties = result['penalties'] as List<PenaltyModel>;

      double total = 0.0;
      for (var penalty in penalties) {
        if (!penalty.isPaid && !penalty.isWaived) {
          total += penalty.amount;
        }
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }
}