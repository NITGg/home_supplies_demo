import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AnimatedGoButton extends StatefulWidget {
  const AnimatedGoButton({super.key});

  @override
  State<AnimatedGoButton> createState() => _AnimatedGoButtonState();
}

class _AnimatedGoButtonState extends State<AnimatedGoButton> {
  bool _showPlus = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      setState(() => _showPlus = !_showPlus);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: _showPlus
          ? const Icon(
              Icons.add_circle_outline,
              key: ValueKey(true),
              size: 40,
              color: Colors.white,
            )
          : SvgPicture.asset(
              'assets/images/go.svg',
              key: const ValueKey(false),
              fit: BoxFit.scaleDown,
              height: 40,
            ),
    );
  }
}
