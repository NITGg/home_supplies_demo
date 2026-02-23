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
}