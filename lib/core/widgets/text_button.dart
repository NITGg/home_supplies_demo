import 'package:flutter/material.dart';
import 'package:tawreedat/core/style/text_styles.dart';

class AppTextButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool underline;
  final Color color;

  const AppTextButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.underline = false,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: color,
      ),
      onPressed: onPressed,
      child: Container(
        decoration: underline
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: color, width: 1)),
              )
            : null,
        child: Text(text, style: AppTextStyles.bold14.copyWith(color: color)),
      ),
    );
  }
}
