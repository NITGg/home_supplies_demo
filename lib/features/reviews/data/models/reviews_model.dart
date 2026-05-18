
class ReviewModel {
  final int id;
  final int courierId;
  final int customerId;
  final int orderId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.courierId,
    required this.customerId,
    required this.orderId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
    id: json['id'],
    courierId: json['courier_id'],
    customerId: json['customer_id'],
    orderId: json['order_id'],
    rating: json['rating'],
    comment: json['comment'],
    createdAt: DateTime.parse(json['created_at']).toLocal(),
  );
}

class ReviewsResponse {
  final int totalReviews;
  final int totalPages;
  final List<ReviewModel> reviews;

  ReviewsResponse({
    required this.totalReviews,
    required this.totalPages,
    required this.reviews,
  });

  factory ReviewsResponse.fromJson(Map<String, dynamic> json) =>
      ReviewsResponse(
        totalReviews: json['totalReviews'],
        totalPages: json['totalPages'],
        reviews: (json['reviews'] as List)
            .map((e) => ReviewModel.fromJson(e))
            .toList(),
      );
}