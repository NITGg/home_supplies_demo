import 'package:dio/dio.dart';
import 'package:tawreedat_go/core/utils/logger.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/transaction_penality_models.dart';
import '../models/wallet_model.dart';
import '../models/recharge_model.dart';

class WalletRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<WalletModel> getWalletData() async {
    final response = await _dio.get(
      '/profile/wallet?lang=${LocaleManager.currentLocale}',
    );
    if (response.statusCode == 200) {
      return WalletModel.fromJson(response.data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }

  Future<RechargeModel> initiateRecharge(
    int amountCents, {
    String? provider,
  }) async {
    final body = <String, dynamic>{'amount_cents': amountCents.toString()};
    if (provider != null) body['provider'] = provider;
    //only send this in kashier
    if (provider != null) {
      body['redirection_url'] =
          "https://tawreedat.nitg-eg.com/admin_apis/api/v1/test";
    }
    dLog('📤 POST /profile/wallet/recharge/initiate body=$body');
    final response = await _dio.post(
      '/profile/wallet/recharge/initiate?lang=${LocaleManager.currentLocale}',
      data: body,
    );
    dLog(
      '📥 initiateRecharge status=${response.statusCode} data=${response.data}',
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
    final queryParameters = <String, dynamic>{'page': page, 'limit': limit};
    if (startDate != null) queryParameters['created_at[gte]'] = startDate;
    if (endDate != null) queryParameters['created_at[lte]'] = endDate;
    dLog(queryParameters.toString());
    final response = await _dio.get(
      '/profile/wallet/transactions?lang=${LocaleManager.currentLocale}',
      queryParameters: queryParameters,
    );

    // Response is flat — no 'data' wrapper
    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return {
        'transactions': (data['transactions'] as List)
            .map((json) => WalletTransactionModel.fromJson(json))
            .toList(),
        'pagination': PaginationModel(
          page: page, // not in response, use request value
          limit: limit, // not in response, use request value
          total: data['totalTransactions'] as int? ?? 0,
          totalPages: data['totalPages'] as int? ?? 1,
        ),
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
      '/profile/wallet/penalties?lang=${LocaleManager.currentLocale}&sort=is_paid,created_at',
      queryParameters: {'page': page, 'limit': limit},
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return {
        'penalties': (data['penalties'] as List)
            .map((json) => PenaltyModel.fromJson(json))
            .toList(),
        'pagination': PaginationModel(
          page: page,
          limit: limit,
          total: data['totalPenalties'] as int? ?? 0,
          totalPages: data['totalPages'] as int? ?? 1,
        ),
        'totalPenaltyAmount':
            (num.tryParse(data['totalPenaltiesAmount']?.toString() ?? '0') ??
                0) /
            1,
      };
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }
}
