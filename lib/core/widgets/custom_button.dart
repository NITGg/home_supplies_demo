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

  /// When true the button continuously shakes to nudge the user to tap it.
  /// Toggle it off once the user has interacted or the guidance is no longer needed.
  final bool shake;

  const AppCustomButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isSecondary,
    this.isDelete,
    this.isLoading = false,
    this.enabled = true,
    this.shake = false,
  });

  @override
  State<AppCustomButton> createState() => _AppCustomButtonState();
}

class _AppCustomButtonState extends State<AppCustomButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  // ── Shake animation ───────────────────────────────────────────────────────
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  // Shake: quick left-right oscillation then a pause before repeating.
  // Values go  0 → +1 → -1 → +1 → -1 → 0  then idle until next repeat.
  static final _shakeTween = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: -1.0), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -1.0, end: 1.0), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: -1.0), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -1.0, end: 0.0), weight: 1),
    // Silent pause — hold at 0 before the next cycle
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 6),
  ]);

  bool get _isInteractable => widget.enabled && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _shakeAnimation = _shakeTween.animate(_shakeController);

    if (widget.shake) _shakeController.repeat();
  }

  @override
  void didUpdateWidget(AppCustomButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _shakeController.repeat();
    } else if (!widget.shake && oldWidget.shake) {
      _shakeController.stop();
      _shakeController.value = 0;
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

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
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            // Max horizontal displacement in logical pixels
            const double maxOffset = 6.0;
            return Transform.translate(
              offset: Offset(_shakeAnimation.value * maxOffset, 0),
              child: child,
            );
          },
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
      ),
    );
  }
}