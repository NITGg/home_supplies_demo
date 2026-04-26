import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../manager/cart_cubit.dart';
import '../../manager/cart_state.dart';
import '../../../../core/style/app_colors.dart';

/// A cart icon badge that:
/// - Shows the total item count from [CartCubit].
/// - Plays a spring-bounce animation whenever the count increases.
///
/// Drop it into any [AppBar.actions] that has [CartCubit] in context.
class AnimatedCartIcon extends StatefulWidget {
  final VoidCallback onTap;

  const AnimatedCartIcon({super.key, required this.onTap});

  @override
  State<AnimatedCartIcon> createState() => _AnimatedCartIconState();
}

class _AnimatedCartIconState extends State<AnimatedCartIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Spring: grow → overshoot → settle.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.40)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.40, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: BlocConsumer<CartCubit, CartState>(
        // Only re-listen / rebuild when the total item count changes.
        listenWhen: (prev, curr) {
          final p = prev is CartLoaded ? prev.data.summary.totalItems : 0;
          final c = curr is CartLoaded ? curr.data.summary.totalItems : 0;
          return c > p; // bounce only on increase
        },
        listener: (_, __) => _ctrl.forward(from: 0),
        buildWhen: (prev, curr) {
          final p = prev is CartLoaded ? prev.data.summary.totalItems : 0;
          final c = curr is CartLoaded ? curr.data.summary.totalItems : 0;
          return p != c;
        },
        builder: (context, state) {
          final count = (state is CartLoaded
              ? state.data.summary.totalItems
              : 0)
              .clamp(0, 99);

          return ScaleTransition(
            scale: _scale,
            child: InkWell(
              onTap: widget.onTap,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                child: Badge.count(
                  backgroundColor: AppColors.kSecondaryColor,
                  textColor: AppColors.kPrimaryColor,
                  isLabelVisible: count > 0,
                  count: count,
                  largeSize: 10,
                  alignment: Alignment.topRight,
                  child: Icon(
                    count > 0
                        ? Icons.shopping_cart_rounded
                        : Icons.shopping_cart_outlined,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}