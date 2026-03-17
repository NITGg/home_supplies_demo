// lib/features/wallet/data/repositories/wallet_repo.dart

import '../data_source/wallet_remote_data_source.dart';
import '../models/wallet_model.dart';
import '../models/recharge_model.dart';

class WalletRepository {
  final WalletRemoteDataSource remoteDataSource;

  WalletRepository({required this.remoteDataSource});

  Future<WalletModel> getWalletData() async {
    return await remoteDataSource.getWalletData();
  }

  Future<RechargeModel> initiateRecharge(int amountCents) async {
    return await remoteDataSource.initiateRecharge(amountCents);
  }

  // ==================== Get Transactions ====================
  Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    return await remoteDataSource.getTransactions(
      page: page,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // ==================== Get Penalties ====================
  Future<Map<String, dynamic>> getPenalties({
    int page = 1,
    int limit = 20,
  }) async {
    return await remoteDataSource.getPenalties(
      page: page,
      limit: limit,
    );
  }
}