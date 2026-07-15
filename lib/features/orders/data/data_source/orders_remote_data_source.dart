
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/exception/api_exeption_mapper.dart';
import '../../../../core/utils/location_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../../../auth/manager/profile_cubit.dart';
import '../models/orders_model.dart';

class OrderDataSource {
  final ApiClient _apiClient = ApiClient.instance;

  // ── Location cache ────────────────────────────────────────────────────────
  // Re-using the last known position avoids a full GPS round-trip on every
  // socket-triggered reload.  The cache is considered stale after 45 seconds
  // or when the caller explicitly requests a fresh position.
  static const _locationCacheTtl = Duration(seconds: 45);
  dynamic _cachedPosition; // same type returned by LocationService
  DateTime? _lastLocationFetch;

  /// Returns the cached position when it is still fresh, otherwise fetches a
  /// new one and updates the cache.
  Future<dynamic> _getPosition({
    required BuildContext context,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final isFresh = _cachedPosition != null &&
        _lastLocationFetch != null &&
        now.difference(_lastLocationFetch!) < _locationCacheTtl;

    if (!forceRefresh && isFresh) return _cachedPosition;

    if (forceRefresh) {
      // Pull-to-refresh: user expects accurate location, wait for it
      final position = await LocationService.instance.getCurrentLocation(context: context);
      _cachedPosition = position;
      _lastLocationFetch = DateTime.now();
      return position;
    }

    // Socket-triggered / background reload: use last-known instantly
    final position = await LocationService.instance.getLastKnownOrCurrent(context: context);
    _cachedPosition = position;
    _lastLocationFetch = DateTime.now();
    return position;
  }

  /// Invalidate the cached position (call this if the user explicitly
  /// triggers a pull-to-refresh so they always get an up-to-date location).
  void invalidateLocationCache() {
    _cachedPosition = null;
    _lastLocationFetch = null;
  }

  /// Get available orders (pending orders) with pagination.
  ///
  /// [forceRefreshLocation] – pass `true` only on explicit pull-to-refresh so
  /// the user always sees orders relative to their current position.  All
  /// socket-triggered reloads pass `false` (default) to reuse the cache.
  Future<Map<String, dynamic>> getAvailableOrders({
    int page = 1,
    int limit = 20,
    double? minBudget,
    double? maxBudget,
    required BuildContext context,
    bool forceRefreshLocation = false,
  }) async {
    try {
      final position = await _getPosition(
        context: context,
        forceRefresh: forceRefreshLocation,
      );

      final response = await _apiClient.dio.get(
        '/order/available-orders',
        queryParameters: {
          'page': page,
          'limit': limit,
          'lang': LocaleManager.currentLocale,
          'latitude': position?.latitude,
          'longitude': position?.longitude,
          if (minBudget != null)
            "priceFrom": ((minBudget * 100).round()).toString(),
          if (maxBudget != null)
            "priceTo": ((maxBudget * 100).round()).toString(),
        },
      );
      dLog('Get orders response: ${response.data}');

      final orders = (response.data['data']['orders'] as List)
          .map((order) => OrderModel.fromJson(order))
          .toList();

      final priceRangeJson = response.data['data']['priceRange'];
      final priceRange = priceRangeJson != null
          ? PriceRangeModel.fromJson(priceRangeJson)
          : null;
      dLog('Available orders priceRange: $priceRangeJson');

      return {
        'orders': orders,
        'pagination': response.data['data']['pagination'],
        'priceRange': priceRange,
      };
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  /// Get order history with filters and pagination
  Future<Map<String, dynamic>> getOrderHistory({
    int page = 1,
    int limit = 20,
    String filter = 'all', // all, completed, cancelled
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/order/history',
        queryParameters: {
          if (filter != 'all') 'status': filter,
          'page': page,
          'limit': limit,
          'lang': LocaleManager.currentLocale,
        },
      );

      final orders = (response.data['data']['orders'] as List)
          .map((order) => OrderModel.fromJson(order))
          .toList();

      return {
        'orders': orders,
        'pagination': response.data['data']['pagination'],
      };
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  /// Submit offer (proposal) for an order
  Future<ProposalModel> submitOffer({
    required int orderId,
    required int totalFee,
    required double distanceToPickup,
    required int timeToPickup,
    required int vehicleId,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/order/submit-offer/$orderId',
        queryParameters: {'lang': LocaleManager.currentLocale},
        data: {
          'total_fee': totalFee,
          'distance_to_pickup': distanceToPickup,
          'estimated_arrival_at_pickup': timeToPickup,
          'vehicle_id': vehicleId,
        },
      );
      return ProposalModel.fromJson(response.data['data']['proposal']);
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  /// Respond to a fixed-fee order with ACCEPT or REJECT
  Future<void> respondToFixedFee({
    required int orderId,
    required String action, // 'ACCEPT' or 'REJECT'
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/order/fixed-fee-response/$orderId',
        queryParameters: {'lang': LocaleManager.currentLocale},
        data: {'action': action},
      );
      dLog('respondToFixedFee [$action] response: ${response.data}');
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  /// Get active order (order in progress)
  Future<List<OrderModel>> getActiveOrder() async {
    try {
      final response = await _apiClient.dio.get(
        '/order/active-order',
        queryParameters: {'lang': LocaleManager.currentLocale},
      );

      final data = response.data['data']['order'];
      if (data == null) return [];
      if (data is List) {
        return data.map((o) => OrderModel.fromJson(o)).toList();
      }
      return [OrderModel.fromJson(data)];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  Future<OrderModel> getOrderById(int orderId) async {
    try {
      final response = await _apiClient.dio.get(
        '/order/order-details/$orderId',
        queryParameters: {'lang': LocaleManager.currentLocale},
      );
      return OrderModel.fromJson(response.data['data']['order']);
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  /// Complete delivery and get QR code
  Future<QrCodeModel> completeDelivery({
    required int orderId,
    required double actualPrice,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/order/complete-delivery/$orderId',
        queryParameters: {'lang': LocaleManager.currentLocale},
        data: {'actual_price': (actualPrice * 100).round()},
      );

      return QrCodeModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  /// Report high price (budget not enough)
  Future<OrderModel> reportHighPrice({
    required int orderId,
    required double actualPrice,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/order/report-order-high-price/$orderId',
        queryParameters: {'lang': LocaleManager.currentLocale},
        data: {'actual_price': (actualPrice * 100).round()},
      );

      return OrderModel.fromJson(response.data['data']['order']);
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  /// Cancel order - product unavailable
  Future<OrderModel> cancelOrderUnavailable({
    required int orderId,
    required String note,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/order/cancel-unavailable/$orderId',
        queryParameters: {'lang': LocaleManager.currentLocale},
        data: {'note': note},
      );

      return OrderModel.fromJson(response.data['data']['order']);
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  /// Cancel order - other reason
  Future<OrderModel> cancelOrderOther({
    required int orderId,
    required String note,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/order/cancel-other/$orderId',
        queryParameters: {'lang': LocaleManager.currentLocale},
        data: {'reason': note},
      );

      return OrderModel.fromJson(response.data['data']['order']);
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  /// check wallet limit is ok
  Future<bool> aboveWalletLimit(BuildContext context) async {
    final response = await _apiClient.dio.get('/wallet/total-fines');
    if (context.mounted) {
      return response.data['data']['total'] >
          context.read<ProfileCubit>().currentVehicleWalletLimitValue ??
          10000;
    } else {
      dLog('no context wallet limit');
      return false;
    }
  }

  Future<OrderModel> markOrderCollected({required int orderId}) async {
    try {
      final response = await _apiClient.dio.post(
        '/order/order-collected/$orderId',
        queryParameters: {'lang': LocaleManager.currentLocale},
      );
      return OrderModel.fromJson(response.data['data']['order']);
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  Future<void> confirmWithOtp({
    required int orderId,
    required double actualPrice,
    required String otp,
  }) async {
    try {
      var response = await _apiClient.dio.post(
        '/order/complete-delivery/$orderId',
        queryParameters: {'lang': LocaleManager.currentLocale},
        data: {
          "actual_price": (actualPrice * 100).round(),
          "confirmation_otp": otp,
        },
      );
      dLog('confirmWithOtp success : ${response.data.toString()}');
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  Future<void> confirmDeliveryFinal({
    required int orderId,
    required int courierId,
  }) async {
    try {
      var response = await _apiClient.dio2.post(
        '/orders/confirm-delivery',
        queryParameters: {'lang': LocaleManager.currentLocale},
        data: {"order_id": orderId, "courier_id": courierId},
      );
      dLog('confirmDeliveryFinal : ${response.toString()}');
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }
}