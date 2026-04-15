import 'package:flutter/material.dart';

Widget buildPinIcon({
  required IconData icon,
  required Color color,
  required Color bgColor,
  bool warning = false,
}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      if (warning)
        Positioned(
          right: -3,
          top: -3,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              size: 9,
              color: Colors.white,
            ),
          ),
        ),
    ],
  );
}