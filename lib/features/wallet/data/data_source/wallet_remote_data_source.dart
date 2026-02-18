import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/wallet_model.dart';

class WalletRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<WalletModel> getWalletData() async {
    final response = await _dio.get('/profile/wallet');
    if (response.statusCode == 200) {
      return WalletModel.fromJson(response.data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }
}