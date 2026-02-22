import 'package:flutter/material.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../data/models/reviews_model.dart';

class ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar placeholder
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.kPrimaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${review.orderId}',
                      style: AppTextStyles.bold14
                          .copyWith(color: AppColors.kSecondaryColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(review.createdAt),
                      style: AppTextStyles.regular14
                          .copyWith(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Star rating badge
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _ratingColor(review.rating).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded,
                        color: _ratingColor(review.rating), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${review.rating}',
                      style: AppTextStyles.bold14
                          .copyWith(color: _ratingColor(review.rating)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Stars row
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) => Icon(
              i < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
              color: i < review.rating
                  ? AppColors.kPrimaryColor
                  : Colors.grey.shade300,
              size: 20,
            )),
          ),

          // Comment
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.kBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                review.comment!,
                style: AppTextStyles.regular14
                    .copyWith(color: AppColors.kSecondaryColor, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _ratingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating == 3) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}