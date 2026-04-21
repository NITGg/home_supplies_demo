class AdModel {
  final int id;
  final String title;
  final String titleAr;
  final String description;
  final String descriptionAr;
  final String imageUrl;
  final String targetUrl;
  final String? mobileScreen;
  final String startDate;
  final String endDate;
  final int budget;
  final int priority;
  final String status;
  final String placement;
  final String adType;
  final String popupSize;
  final bool closable;
  final int durationSeconds;
  final String createdAt;
  final String updatedAt;

  AdModel({
    required this.id,
    required this.title,
    required this.titleAr,
    required this.description,
    required this.descriptionAr,
    required this.imageUrl,
    required this.targetUrl,
    this.mobileScreen,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.priority,
    required this.status,
    required this.placement,
    required this.adType,
    required this.popupSize,
    required this.closable,
    required this.durationSeconds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdModel.fromJson(Map<String, dynamic> json) {
    return AdModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      titleAr: json['title_ar'] ?? '',
      description: json['description'] ?? '',
      descriptionAr: json['description_ar'] ?? '',
      imageUrl: json['image_url'] ?? '',
      targetUrl: json['target_url'] ?? '',
      mobileScreen: json['mobile_screen'],
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      budget: int.tryParse(json['budget'].toString()) ?? 0,
      priority: json['priority'] ?? 0,
      status: json['status'] ?? '',
      placement: json['placement'] ?? '',
      adType: json['ad_type'] ?? '',
      popupSize: json['popup_size'] ?? '',
      closable: json['closable'] ?? false,
      durationSeconds: json['duration_seconds'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

class AdsResponse {
  final List<AdModel> ads;
  final int totalCount;
  final int totalPages;

  AdsResponse({
    required this.ads,
    required this.totalCount,
    required this.totalPages,
  });

  factory AdsResponse.fromJson(Map<String, dynamic> json) {
    final adsList = (json['ads'] as List? ?? [])
        .map((ad) => AdModel.fromJson(ad))
        .toList();

    return AdsResponse(
      ads: adsList,
      totalCount: json['totalCount'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}
