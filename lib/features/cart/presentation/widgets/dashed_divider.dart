import 'package:flutter/material.dart';

class DashedDivider extends StatelessWidget {
  final Color color;

  const DashedDivider({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const dashWidth = 6.0;
        const gapWidth = 4.0;
        final count = (constraints.maxWidth / (dashWidth + gapWidth)).floor();
        return Row(
          children: List.generate(
            count,
                (_) => Container(
              width: dashWidth,
              height: 1,
              margin: const EdgeInsets.only(right: gapWidth),
              color: color,
            ),
          ),
        );
      },
    );
  }
}