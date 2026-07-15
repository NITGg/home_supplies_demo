
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tawreedat_courier/core/widgets/banners.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../l10n/app_localizations.dart';

class SupplierReviewBottomSheet extends StatefulWidget {
  final int orderId;

  const SupplierReviewBottomSheet({
    super.key,
    required this.orderId,
  });

  @override
  State<SupplierReviewBottomSheet> createState() =>
      _SupplierReviewBottomSheetState();
}

class _SupplierReviewBottomSheetState extends State<SupplierReviewBottomSheet> {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final l10n = AppLocalizations.of(context)!;

    if (_selectedRating == 0) {
      showInfoBanner(context, l10n.pleaseSelectRating);
      return;
    }

    setState(() => _isLoading = true);

    try {
      dLog('submitting supplier review for order ${widget.orderId}, rating: $_selectedRating');
      final response = await ApiClient.instance.dio.post(
        '/review/submit-supplier-review/${widget.orderId}',
        data: {
          "rating": _selectedRating,
          "comment": _commentController.text.trim(),
        },
      );
      dLog('supplier review response: ${response.statusCode} | ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        dLog('supplier review submitted successfully for order ${widget.orderId}, rating: $_selectedRating');
        if (mounted) {
          showSuccessBanner(context, l10n.reviewSubmitted);
          Navigator.of(context).pop();
        }
      }
    } on DioException catch (e) {
      dLog('supplier review failed: ${e.response?.statusCode} | ${e.response?.data} | ${e.message}');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              l10n.rateTheSupplier,
              style: AppTextStyles.bold18.copyWith(
                color: AppColors.kSecondaryColor,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              l10n.howWasYourExperienceWithSupplier,
              textAlign: TextAlign.center,
              style: AppTextStyles.regular14.copyWith(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final star = index + 1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = star),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      star <= _selectedRating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      key: ValueKey('$star-${star <= _selectedRating}'),
                      size: 48,
                      color: star <= _selectedRating
                          ? Colors.amber.shade600
                          : Colors.grey.shade300,
                    ),
                  ),
                );
              }),
            ),

            if (_selectedRating > 0) ...[
              const SizedBox(height: 6),
              Text(
                _ratingLabel(l10n, _selectedRating),
                style: AppTextStyles.bold14.copyWith(
                  color: Colors.amber.shade700,
                ),
              ),
            ],

            const SizedBox(height: 24),

            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: l10n.leaveAComment,
                hintStyle: AppTextStyles.regular14.copyWith(
                  color: Colors.grey.shade400,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.kPrimaryColor),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.skip,
                      style: AppTextStyles.bold14.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  flex: 2,
                  child: AppCustomButton(
                    onPressed: _submitReview,
                    text: l10n.submitReview,
                    isLoading: _isLoading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(AppLocalizations l10n, int rating) {
    switch (rating) {
      case 1:
        return l10n.ratingPoor;
      case 2:
        return l10n.ratingFair;
      case 3:
        return l10n.ratingGood;
      case 4:
        return l10n.ratingVeryGood;
      case 5:
        return l10n.ratingExcellent;
      default:
        return '';
    }
  }
}
