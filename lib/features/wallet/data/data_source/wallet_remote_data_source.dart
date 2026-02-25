// lib/features/wallet/data/data_source/wallet_remote_data_source.dart

import 'dart:developer';

import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/wallet_model.dart';
import '../models/recharge_model.dart';

class WalletRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<WalletModel> getWalletData() async {
    final response = await _dio.get('/profile/wallet');
    if (response.statusCode == 200) {
      log(response.data.toString());
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
      '/profile/wallet/recharge/initiate',
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
}