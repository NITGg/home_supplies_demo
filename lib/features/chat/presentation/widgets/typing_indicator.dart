import 'package:flutter/material.dart';

/// Shows an animated "…" indicator aligned to the left (incoming side).
///
/// Pass [name] to show "Ahmed is typing…" or leave null for a bare indicator.
class TypingIndicator extends StatefulWidget {
  final String? name;

  const TypingIndicator({super.key, this.name});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 0, bottom: 4, top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.name != null) ...[
              Text(
                '${widget.name} ',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
              ),
            ],
            _AnimatedDot(controller: _controller, delay: 0.0),
            const SizedBox(width: 3),
            _AnimatedDot(controller: _controller, delay: 0.2),
            const SizedBox(width: 3),
            _AnimatedDot(controller: _controller, delay: 0.4),
          ],
        ),
      ),
    );
  }
}

class _AnimatedDot extends StatelessWidget {
  final AnimationController controller;
  final double delay;

  const _AnimatedDot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Stagger: offset each dot by [delay] in the 0-1 animation cycle.
        final t = ((controller.value - delay) % 1.0).abs();
        // Map t to a smooth bounce: peak at 0.4, trough at 0.0 and 0.8+
        final scale = t < 0.4
            ? 1.0 + (t / 0.4) * 0.5   // rise 1.0 → 1.5
            : t < 0.8
                ? 1.5 - ((t - 0.4) / 0.4) * 0.5  // fall 1.5 → 1.0
                : 1.0;

        final opacity = t < 0.5 ? 0.4 + t * 1.2 : 1.0 - (t - 0.5) * 0.8;

        return Transform.scale(
          scale: scale.clamp(1.0, 1.5),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(opacity.clamp(0.3, 0.9)),
            ),
          ),
        );
      },
    );
  }
}
