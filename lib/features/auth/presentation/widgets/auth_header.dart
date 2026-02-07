import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class AuthHeaderImage extends StatelessWidget {
  const AuthHeaderImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Image.asset(
          'assets/images/login/login_header_background.png',
          fit: BoxFit.cover,
          width: double.infinity,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Center(
            child: SvgPicture.asset('assets/images/login/login_header.svg'),
          ),
        ),
      ],
    );
  }
}
