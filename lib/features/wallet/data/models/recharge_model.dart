
// lib/features/wallet/data/models/recharge_model.dart

class RechargeModel {
  final String message;
  final String provider;
  final int transactionId;
  final String checkoutUrl;

  // Paymob-specific
  final String? clientSecret;
  final int? intentionOrderId;

  // Kashier-specific
  final String? sessionId;

  RechargeModel({
    required this.message,
    required this.provider,
    required this.transactionId,
    required this.checkoutUrl,
    this.clientSecret,
    this.intentionOrderId,
    this.sessionId,
  });

  factory RechargeModel.fromJson(Map<String, dynamic> json) {
    return RechargeModel(
      message: json['message'] ?? '',
      provider: json['provider'] ?? 'paymob',
      transactionId: json['transactionId'],
      checkoutUrl: json['checkoutUrl'] ?? '',
      clientSecret: json['clientSecret'],
      intentionOrderId: json['intentionOrderId'],
      sessionId: json['sessionId'],
    );
  }
}