
// lib/features/wallet/data/models/recharge_model.dart

class RechargeModel {
  final String message;
  final int transactionId;
  final String clientSecret;
  final String checkoutUrl;
  final int intentionOrderId;

  RechargeModel({
    required this.message,
    required this.transactionId,
    required this.clientSecret,
    required this.checkoutUrl,
    required this.intentionOrderId,
  });

  factory RechargeModel.fromJson(Map<String, dynamic> json) {
    return RechargeModel(
      message: json['message'] ?? '',
      transactionId: json['transactionId'],
      clientSecret: json['clientSecret'] ?? '',
      checkoutUrl: json['checkoutUrl'] ?? '',
      intentionOrderId: json['intentionOrderId'],
    );
  }
}