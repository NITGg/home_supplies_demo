import 'package:flutter/material.dart';

import '../style/app_colors.dart';
import '../style/text_styles.dart';

class AppCustomButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final bool? isSecondary;
  final bool? isDelete;
  final bool isLoading;

  const AppCustomButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isSecondary,
    this.isDelete,
    this.isLoading = false,
  });

  @override
  State<AppCustomButton> createState() => _AppCustomButtonState();
}

class _AppCustomButtonState extends State<AppCustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSecondary = widget.isSecondary ?? false;
    final isDelete = widget.isDelete ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
      child: GestureDetector(
        onTapDown: widget.isLoading
            ? null
            : (_) => setState(() => _isPressed = true),
        onTapUp: widget.isLoading
            ? null
            : (_) => setState(() => _isPressed = false),
        onTapCancel: widget.isLoading
            ? null
            : () => setState(() => _isPressed = false),
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: widget.isLoading
                ? Colors.grey.shade400
                : (isSecondary
                      ? AppColors.kSecondaryColor
                      : isDelete
                      ? Colors.redAccent
                      : AppColors.kPrimaryColor),
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.isLoading
                ? null
                : [
                    BoxShadow(
                      color:
                          (isSecondary
                                  ? AppColors.kSecondaryColor
                                  :  isDelete
                              ? Colors.redAccent
                              : AppColors.kPrimaryColor)
                              .withOpacity(_isPressed ? 0.2 : 0.3),
                      blurRadius: _isPressed ? 8 : 12,
                      offset: Offset(0, _isPressed ? 2 : 4),
                      spreadRadius: _isPressed ? 0 : 1,
                    ),
                  ],
          ),
          height: 54,
          width: double.infinity,
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    widget.text,
                    style: isSecondary
                        ? AppTextStyles.bold18.copyWith(
                            color: AppColors.kPrimaryColor,
                          )
                        : AppTextStyles.bold18,
                  ),
          ),
        ),
      ),
    );
  }
}
