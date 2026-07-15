import 'package:dio/dio.dart';

import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/exception/api_exeption_mapper.dart';
import '../../../../core/utils/exception/app_exception.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/coupns_model.dart';

class CouponDataSource {
  final ApiClient _apiClient = ApiClient.instance;
  static const String _base = '/coupon';

  Future<List<AvailableCouponModel>> getAvailableCoupons() async {
    try {
      final response = await _apiClient.dio
          .get('$_base/list-available?lang=${LocaleManager.currentLocale}');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final list = response.data['data']['coupons'] as List;
        return list.map((e) => AvailableCouponModel.fromJson(e)).toList();
      }
      throw const ParseException('Coupons data missing from response.');
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  Future<ActiveCouponModel?> getActiveCoupon() async {
    try {
      final response = await _apiClient.dio
          .get('$_base/active?lang=${LocaleManager.currentLocale}');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data']['activeCoupon'];
        if (data == null) return null;
        return ActiveCouponModel.fromJson(data);
      }
      throw const ParseException('Active coupon data missing from response.');
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  Future<Map<String, dynamic>> getCouponHistory({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '$_base/history?lang=${LocaleManager.currentLocale}',
        queryParameters: {'page': page, 'limit': limit},
      );
      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data'];
        return {
          'history': (data['couponHistory'] as List)
              .map((e) => ActiveCouponModel.fromJson(e as Map<String, dynamic>))
              .toList(),
          'pagination': CouponPaginationModel.fromJson(data['pagination']),
        };
      }
      throw const ParseException('Coupon history data missing from response.');
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  Future<void> buyCouponWithWallet(int couponId) async {
    try {
      final response = await _apiClient.dio.post(
          '$_base/buy-coupon/$couponId?lang=${LocaleManager.currentLocale}');
      if (response.statusCode != 201) {
        throw BadRequestException(
            response.data?['message'] ?? 'Failed to buy coupon');
      }
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  Future<void> buyCouponWithPoints(int couponId) async {
    try {
      final response = await _apiClient.dio.post(
        '/points/buy-coupon-using-points/$couponId?lang=${LocaleManager.currentLocale}',
      );
      if (response.statusCode != 201) {
        throw BadRequestException(
            response.data?['message'] ?? 'Failed to buy coupon with points');
      }
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }
}