// social_auth_button_row.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/auth/presentation/widgets/social_button.dart';

import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';

class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50.0),
      child: Column(
        spacing: 20,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (Platform.isIOS)
            SocialLoginButton(
              title: AppLocalizations.of(context)!.appleSignin,
              onPressed: () => context.read<AuthCubit>().signInWithApple(),
              assetPath: 'assets/images/login/apple.svg',
            ),
          SocialLoginButton(
            title: AppLocalizations.of(context)!.googleSignin,
            onPressed: () => context.read<AuthCubit>().signInWithGoogle(),
            assetPath: 'assets/images/login/google.svg',
          ),
        ],
      ),
    );
  }
}
