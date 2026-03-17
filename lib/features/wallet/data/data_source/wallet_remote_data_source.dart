
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/transaction_penality_models.dart';
import '../models/wallet_model.dart';
import '../models/recharge_model.dart';

class WalletRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<WalletModel> getWalletData() async {
    final response = await _dio.get('/profile/wallet?lang=${LocaleManager.currentLocale}');
    if (response.statusCode == 200) {
      return WalletModel.fromJson(response.data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }

  Future<RechargeModel> initiateRecharge(int amountCents) async {
    final response = await _dio.post(
      '/profile/wallet/recharge/initiate?lang=${LocaleManager.currentLocale}',
      data: {'amount_cents': amountCents.toString()},
    );
    if (response.statusCode == 201) {
      return RechargeModel.fromJson(response.data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }

  // ==================== Get Transactions ====================
  Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (startDate != null) queryParameters['created_atFrom'] = startDate;
    if (endDate != null) queryParameters['created_atTo'] = endDate;

    final response = await _dio.get(
      '/admin/wallet/transactions?lang=${LocaleManager.currentLocale}',
      queryParameters: queryParameters,
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      final data = response.data['data'];
      return {
        'transactions': (data['userTransactions'] as List)
            .map((json) => WalletTransactionModel.fromJson(json))
            .toList(),
        'pagination': PaginationModel.fromJson(data['pagination']),
      };
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }

  // ==================== Get Penalties ====================
  Future<Map<String, dynamic>> getPenalties({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/admin/wallet/penalties?lang=${LocaleManager.currentLocale}',
      queryParameters: {'page': page, 'limit': limit},
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      final data = response.data['data'];
      return {
        'penalties': (data['penalties'] as List)
            .map((json) => PenaltyModel.fromJson(json))
            .toList(),
        'pagination': PaginationModel.fromJson(data['pagination']),
      };
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }
}