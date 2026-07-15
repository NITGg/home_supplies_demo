import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class AuthHeaderImage extends StatelessWidget {
  const AuthHeaderImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
      ),
      child: AspectRatio(
        aspectRatio: 3,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SvgPicture.asset(
            'assets/images/logo_go.svg',
            fit: BoxFit.scaleDown,
          ),
        ),
      ),
    );
  }
}
