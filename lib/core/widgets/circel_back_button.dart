import 'package:flutter/material.dart';

class CircleBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CircleBackButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey.shade200,
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: Colors.grey.shade700,
          ),
          onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}