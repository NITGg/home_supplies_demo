import '../data_source/wallet_remote_data_source.dart';
import '../models/wallet_model.dart';

class WalletRepository {
  final WalletRemoteDataSource remoteDataSource;

  WalletRepository({required this.remoteDataSource});

  Future<WalletModel> getWalletData() async {
    return await remoteDataSource.getWalletData();
  }
}