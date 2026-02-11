import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/wallet_model.dart';

class WalletRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<WalletModel> getWalletData() async {
    try {
      final response = await _dio.get(
        '/profile/wallet',
      );

      if (response.statusCode == 200) {
        return WalletModel.fromJson(response.data);
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Failed to fetch wallet data',
        );
      }
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}