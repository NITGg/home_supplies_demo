import 'package:flutter/material.dart';
import '../style/app_colors.dart';
import '../style/text_styles.dart';

class HalfButton extends StatelessWidget {
  final bool? flipBorderRadius;
  final String? text;
  final VoidCallback onPressed;

  const HalfButton({
    super.key,
    required this.onPressed,
    this.flipBorderRadius,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.kPrimaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: flipBorderRadius ?? false
                ? const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  )
                : const BorderRadius.only(
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
        child: text != null
            ? Text(text!, style: AppTextStyles.bold14.copyWith(fontSize: 10))
            : Icon(
                flipBorderRadius ?? false
                    ? Icons.arrow_forward
                    : Icons.arrow_back,
                color: Colors.black,
              ),
      ),
    );
  }
}
