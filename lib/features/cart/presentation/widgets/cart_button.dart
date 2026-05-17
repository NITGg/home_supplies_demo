
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../manager/cart_cubit.dart';
import '../../manager/cart_state.dart';
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