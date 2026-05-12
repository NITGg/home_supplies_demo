import 'package:dio/dio.dart';

import '../../core/utils/api_client.dart';
import '../../core/utils/logger.dart';

/// MODEL
class FaqModel {
  final int id;
  final String question;
  final String answer;
  final String language;
  final String createdAt;
  final String updatedAt;

  FaqModel({
    required this.id,
    required this.question,
    required this.answer,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FaqModel.fromJson(Map<String, dynamic> json) {
    return FaqModel(
      id: json['id'] ?? 0,
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      language: json['language'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }
}

/// RESPONSE WRAPPER
class FaqsResponse {
  final List<FaqModel> faqs;

  FaqsResponse({required this.faqs});

  factory FaqsResponse.fromJson(Map<String, dynamic> json) {
    final faqsList =
        (json['faqs'] as List?)?.map((e) => FaqModel.fromJson(e)).toList() ??
        [];

    return FaqsResponse(faqs: faqsList);
  }
}

/// MANAGER
class FaqManager {
  static final FaqManager _instance = FaqManager._internal();

  factory FaqManager() => _instance;

  FaqManager._internal();

  FaqsResponse? _faqsResponse;
  final Dio _dio = ApiClient.instance.dio;

  FaqsResponse? get data => _faqsResponse;

  bool get isLoaded => _faqsResponse != null;

  Future<void> loadFaqs() async {
    try {
      final response = await _dio.get('/faqs?sort=sort_id?target_user[in]=["ALL", "CUSTOMER"]&is_active=true');
      if (response.statusCode == 200 && response.data['faqs'] != null) {
        _faqsResponse = FaqsResponse.fromJson(response.data);
        dLog('✅ FAQs loaded successfully');
      } else {
        dLog('⚠️ Failed to load FAQs: ${response.statusCode}');
      }
    } catch (e, s) {
      dLog('❌ Error loading FAQs: $e $s');
    }
  }
}
