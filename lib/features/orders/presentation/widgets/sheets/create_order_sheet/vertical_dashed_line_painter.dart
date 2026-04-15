import 'package:flutter/material.dart';

class VerticalDashedLinePainter extends CustomPainter {
  final Color color;

  const VerticalDashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashH = 4.0;
    const gap = 4.0;
    double y = 0;
    final x = size.width / 2;

    while (y < size.height) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + dashH).clamp(0, size.height)),
        paint,
      );
      y += dashH + gap;
    }
  }

  @override
  bool shouldRepaint(VerticalDashedLinePainter old) => old.color != color;
}