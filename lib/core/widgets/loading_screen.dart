import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;

class LoadingScreen extends StatefulWidget {
  final bool asWidget;
  final bool isOne;
  final bool isSplash;
  final VoidCallback? onComplete;

  const LoadingScreen({
    super.key,
    this.asWidget = false,
    this.isOne = false,
    this.isSplash = false,
    this.onComplete,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Slightly faster feels snappier
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (widget.isSplash) {
      _controller.forward().whenComplete(() {
        widget.onComplete?.call();
      });
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loadingAnimation = AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isSplash) ...[
              FadeTransition(
                opacity: _fadeAnimation,
                child: SvgPicture.asset(
                  'assets/images/appbar/logo.svg',
                  height: 200,
                ),
              ),
              const SizedBox(height: 24),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.isOne) ...[
                  _buildSideLoader(context, isLeft: true),
                  const SizedBox(width: 16),
                ],
                _buildCenterLoader(context),
                if (!widget.isOne) ...[
                  const SizedBox(width: 16),
                  _buildSideLoader(context, isLeft: false),
                ],
              ],
            ),
          ],
        );
      },
    );

    if (widget.asWidget) {
      return loadingAnimation;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(child: loadingAnimation),
      ),
    );
  }

  Widget _buildCenterLoader(BuildContext context) {
    return Transform.scale(
      scale: 1 + (math.sin(_controller.value * 2 * math.pi) * 0.1),
      child: Transform.rotate(
        angle: _controller.value * 2 * math.pi,
        child: SvgPicture.asset(
          'assets/images/loading.svg',
          width: 50,
          // Add semantics for accessibility
          semanticsLabel: 'Loading',
        ),
      ),
    );
  }

  Widget _buildSideLoader(BuildContext context, {required bool isLeft}) {
    final opacityValue = 0.4 + (math.sin(_controller.value * 2 * math.pi) * 0.25);

    return Transform.rotate(
      angle: -(_controller.value * 2 * math.pi),
      child: Opacity(
        opacity: opacityValue.clamp(0.0, 1.0),
        child: SvgPicture.asset(
          'assets/images/loading.svg',
          width: 45,
          colorFilter: ColorFilter.mode(
            Theme.of(context).primaryColor,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}