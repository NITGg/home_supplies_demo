import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/exception/api_exeption_mapper.dart';
import '../../../../core/utils/exception/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/recharge_model.dart';
import '../models/wallet_models.dart';

class WalletDataSource {
  final ApiClient _apiClient = ApiClient.instance;

  // ==================== Get Wallet Data ====================
  Future<WalletModel> getWalletData() async {
    try {
      final response = await _apiClient.dio
          .get('/wallet/wallet-data?lang=${LocaleManager.currentLocale}');

      if (response.statusCode == 200 && response.data['data'] != null) {
        return WalletModel.fromJson(response.data['data']['wallet']);
      }
      throw const ParseException('Wallet data missing from response.');
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  // ==================== Get Transactions ====================
  Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParameters = <String, dynamic>{'page': page, 'limit': limit};
      if (startDate != null) queryParameters['created_atFrom'] = startDate;
      if (endDate != null) queryParameters['created_atTo'] = endDate;
      dLog('from: $startDate to: $endDate');

      final response = await _apiClient.dio.get(
        '/wallet/list-transaction?lang=${LocaleManager.currentLocale}',
        queryParameters: queryParameters,
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data'];
        dLog(data.toString());
        return {
          'transactions': (data['userTransactions'] as List)
              .map((json) => WalletTransactionModel.fromJson(json))
              .toList(),
          'pagination': PaginationModel.fromJson(data['pagination']),
        };
      }
      throw const ParseException('Transaction data missing from response.');
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  // ==================== Get Penalties (skip/limit) ====================
  Future<Map<String, dynamic>> getPenalties({
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/wallet/list-penalty?lang=${LocaleManager.currentLocale}&sort=is_paid,created_at',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data'] as Map<String, dynamic>;

        dLog('=== PENALTIES RESPONSE (skip=$skip, limit=$limit) ===');
        dLog('totalPenalties: ${data['totalPenalties']}');
        dLog('totalPages: ${data['totalPages']}');

        final total = (data['totalPenalties'] as num?)?.toInt() ?? 0;
        final totalPages = (data['totalPages'] as num?)?.toInt() ?? 0;
        final rawList = data['penalties'] as List;

        final penalties = <PenaltyModel>[];
        for (int i = 0; i < rawList.length; i++) {
          try {
            penalties.add(PenaltyModel.fromJson(rawList[i]));
          } catch (e, st) {
            dLog('❌ PenaltyModel.fromJson FAILED at index $i: $e\n$st');
            rethrow;
          }
        }

        dLog('penalties parsed successfully: ${penalties.length}');
        return {
          'penalties': penalties,
          'pagination': SkipLimitPaginationModel(
            skip: skip,
            limit: limit,
            total: total,
            totalPages: totalPages,
          ),
        };
      }
      throw const ParseException('Penalty data missing from response.');
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  // ==================== Get Unpaid Commissions (skip/limit) ====================
  Future<Map<String, dynamic>> getUnpaidCommissions({
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/wallet/list-unpaid-commission?lang=${LocaleManager.currentLocale}&sort=is_paid,created_at',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data'] as Map<String, dynamic>;

        dLog('=== COMMISSIONS RESPONSE (skip=$skip, limit=$limit) ===');
        dLog('totalUnpaidCommissionAmount: ${data['totalUnpaidCommissionAmount']}');
        dLog('totalPages: ${data['totalPages']}');

        final total =
            (data['totalUnpaidCommissionAmount'] as num?)?.toInt() ?? 0;
        final totalPages = (data['totalPages'] as num?)?.toInt() ?? 0;

        return {
          'commissions': (data['unpaidCommission'] as List)
              .map((json) => UnpaidCommissionModel.fromJson(json))
              .toList(),
          'pagination': SkipLimitPaginationModel(
            skip: skip,
            limit: limit,
            total: total,
            totalPages: totalPages,
          ),
        };
      }
      throw const ParseException('Commission data missing from response.');
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  // ==================== Initiate TopUp ====================
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
    final response = await _apiClient.dio2.post(
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
}