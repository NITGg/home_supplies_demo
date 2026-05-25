import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/refund_model.dart';

class RefundRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  static const _allowedMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};

  Future<void> _validateImage(File file) async {
    final bytes = await file.readAsBytes();
    final mimeType = lookupMimeType(file.path, headerBytes: bytes);
    if (!_allowedMimeTypes.contains(mimeType)) {
      throw Exception('Only JPEG, PNG, or WEBP images are allowed.');
    }
  }

  // ── Get refund reasons ─────────────────────────────────────────────────────

  Future<RefundReasonsResponse> getRefundReasons() async {
    dLog('[Refund] GET /refund-reasons');
    final response = await _dio.get(
      '/refund-reasons',
      queryParameters: {'lang': LocaleManager.currentLocale},
    );
    if (response.statusCode == 200) {
      return RefundReasonsResponse.fromJson(
          response.data as Map<String, dynamic>);
    }
    throw Exception('Failed to load refund reasons');
  }

  // ── Get refunds list ───────────────────────────────────────────────────────

  Future<RefundsListResponse> getRefunds({
    int skip = 0,
    int limit = 20,
  }) async {
    dLog('[Refund] GET /refunds skip=$skip limit=$limit');
    final response = await _dio.get(
      '/refunds',
      queryParameters: {
        'skip': skip,
        'limit': limit,
        'lang': LocaleManager.currentLocale,
      },
    );
    if (response.statusCode == 200) {
      return RefundsListResponse.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception('Failed to load refunds');
  }

  // ── Create refund ──────────────────────────────────────────────────────────

  Future<Refund> createRefund({
    required int orderId,
    required String reason,
    required List<RefundItemRequest> items,
    List<File>? evidenceImages,
  }) async {
    dLog('[Refund] POST /refunds orderId=$orderId items=${items.length} '
        'images=${evidenceImages?.length ?? 0}');

    // Validate images before upload
    if (evidenceImages != null) {
      for (final file in evidenceImages) {
        await _validateImage(file);
      }
    }

    final hasImages = evidenceImages != null && evidenceImages.isNotEmpty;

    late final Response response;

    if (hasImages) {
      final multipartImages = await Future.wait(
        evidenceImages.asMap().entries.map((e) async {
          return MapEntry(
            'evidence_images',
            await MultipartFile.fromFile(
              e.value.path,
              filename:
              'evidence_${orderId}_${e.key}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          );
        }),
      );

      final formData = FormData.fromMap({
        'order_id': orderId,
        'reason': reason,
        // items as repeated fields: items[0][order_item_id], items[0][quantity] …
        for (var i = 0; i < items.length; i++) ...{
          'items[$i][order_item_id]': items[i].orderItemId,
          'items[$i][quantity]': items[i].quantity,
        },
      });

      for (final entry in multipartImages) {
        formData.files.add(entry);
      }

      response = await _dio.post(
        '/refunds?lang=${LocaleManager.currentLocale}',
        data: formData,
      );
    } else {
      response = await _dio.post(
        '/refunds?lang=${LocaleManager.currentLocale}',
        data: {
          'order_id': orderId,
          'reason': reason,
          'items': items.map((e) => e.toJson()).toList(),
        },
      );
    }

    dLog('[Refund] POST /refunds → ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = response.data as Map<String, dynamic>;
      // The API may return the refund nested under 'refund' or at root level
      final refundJson =
      body.containsKey('refund') ? body['refund'] : body;
      return Refund.fromJson(refundJson as Map<String, dynamic>);
    }
    throw Exception('Failed to create refund');
  }
}