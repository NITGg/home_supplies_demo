import 'package:flutter/material.dart';

import '../style/app_colors.dart';
import '../style/text_styles.dart';

class AppCustomButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final bool? isSecondary;
  final bool? isDelete;
  final bool isLoading;
  final bool enabled;

  const AppCustomButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isSecondary,
    this.isDelete,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  State<AppCustomButton> createState() => _AppCustomButtonState();
}

class _AppCustomButtonState extends State<AppCustomButton> {
  bool _isPressed = false;

  bool get _isInteractable => widget.enabled && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final isSecondary = widget.isSecondary ?? false;
    final isDelete = widget.isDelete ?? false;

    final Color activeColor = isSecondary
        ? AppColors.kSecondaryColor
        : isDelete
        ? Colors.redAccent
        : AppColors.kPrimaryColor;

    final Color resolvedColor = !widget.enabled || widget.isLoading
        ? Colors.grey.shade400
        : activeColor;

    return ExcludeFocus(
      excluding: !_isInteractable,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
        child: GestureDetector(
          onTapDown: _isInteractable
              ? (_) => setState(() => _isPressed = true)
              : null,
          onTapUp: _isInteractable
              ? (_) => setState(() => _isPressed = false)
              : null,
          onTapCancel: _isInteractable
              ? () => setState(() => _isPressed = false)
              : null,
          onTap: _isInteractable ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: resolvedColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isInteractable
                  ? [
                BoxShadow(
                  color: activeColor.withOpacity(
                    _isPressed ? 0.2 : 0.3,
                  ),
                  blurRadius: _isPressed ? 8 : 12,
                  offset: Offset(0, _isPressed ? 2 : 4),
                  spreadRadius: _isPressed ? 0 : 1,
                ),
              ]
                  : null,
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
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                widget.text,
                style: isSecondary
                    ? AppTextStyles.bold18.copyWith(
                  color: !widget.enabled
                      ? Colors.white
                      : AppColors.kPrimaryColor,
                )
                    : AppTextStyles.bold18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}