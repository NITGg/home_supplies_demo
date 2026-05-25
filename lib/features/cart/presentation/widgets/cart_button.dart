
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'cart_icon.dart';

class CartButton extends StatelessWidget {
  const CartButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCartIcon(
        onTap: () => context.push('/cart'),
      );
  }
}