class CustomerModel {
  final int id;
  final String fullName;
  final String? personalPhoto;

  CustomerModel({
    required this.id,
    required this.fullName,
    this.personalPhoto,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
    id: json['id'],
    fullName: json['full_name'],
    personalPhoto: json['personal_photo'],
  );
}

class ReviewModel {
  final int id;
  final int? courierId;
  final int? customerId;
  final int? orderId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final CustomerModel? customer;

  ReviewModel({
    required this.id,
    required this.courierId,
    required this.customerId,
    required this.orderId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.customer,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
    id: json['id'],
    courierId: json['courier_id'],
    customerId: json['customer_id'],
    orderId: json['order_id'],
    rating: json['rating'],
    comment: json['comment'],
    createdAt: DateTime.parse(json['created_at']).toLocal(),
    customer: json['customer'] != null
        ? CustomerModel.fromJson(json['customer'])
        : null,
  );
}

class ReviewsResponse {
  final int totalReviews;
  final int totalPages;
  final bool hasNext;
  final List<ReviewModel> reviews;

  ReviewsResponse({
    required this.totalReviews,
    required this.totalPages,
    required this.hasNext,
    required this.reviews,
  });

  // Response shape: { data: { reviews: [...], pagination: { total, total_pages, has_next } } }
  factory ReviewsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final pagination = data['pagination'];
    return ReviewsResponse(
      totalReviews: pagination['total'],
      totalPages: pagination['total_pages'],
      hasNext: pagination['has_next'],
      reviews: (data['reviews'] as List)
          .map((e) => ReviewModel.fromJson(e))
          .toList(),
    );
  }
}