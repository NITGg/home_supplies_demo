class CancellationReason {
  final int id;
  final int roleId;
  final String reasonEn;
  final String reasonAr;

  const CancellationReason({
    required this.id,
    required this.roleId,
    required this.reasonEn,
    required this.reasonAr,
  });

  factory CancellationReason.fromJson(Map<String, dynamic> json) {
    return CancellationReason(
      id: json['id'] as int,
      roleId: json['role_id'] as int,
      reasonEn: json['reason_en'] as String,
      reasonAr: json['reason_ar'] as String,
    );
  }

  /// Returns the localized reason based on the current locale
  String localizedReason(String languageCode) {
    return languageCode == 'ar' ? reasonAr : reasonEn;
  }
}