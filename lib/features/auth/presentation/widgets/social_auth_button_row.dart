// social_auth_button_row.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/auth/presentation/widgets/social_button.dart';

import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

class SocialAuthButtons extends StatelessWidget {
  /// When true, buttons call link endpoints instead of sign-in endpoints.
  final bool isLink;
  /// If set and non-null, the Google link button is hidden.
  final String? googleId;
  /// If set and non-null, the Apple link button is hidden.
  final String? appleId;
  /// Called just before the native social auth UI is launched.
  final VoidCallback? onSocialAuthStarted;
  /// Called after the native social auth UI returns (success or failure).
  final VoidCallback? onSocialAuthEnded;

  const SocialAuthButtons({
    super.key,
    this.isLink = false,
    this.googleId,
    this.appleId,
    this.onSocialAuthStarted,
    this.onSocialAuthEnded,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        spacing: 20,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (Platform.isIOS && !(isLink && appleId != null))
            SocialLoginButton(
              title: isLink ? loc.linkAppleAccount : loc.appleSignin,
              isLoading: context.watch<AuthCubit>().state is AuthLoading,
              onPressed: () {
                onSocialAuthStarted?.call();
                (isLink
                        ? context.read<AuthCubit>().linkWithApple
                        : context.read<AuthCubit>().signInWithApple)()
                    .whenComplete(() => onSocialAuthEnded?.call());
              },
              assetPath: 'assets/images/login/apple.svg',
            ),
          if (!(isLink && googleId != null))
            SocialLoginButton(
              title: isLink ? loc.linkGoogleAccount : loc.googleSignin,
              isLoading: context.watch<AuthCubit>().state is AuthLoading,
              onPressed: () {
                onSocialAuthStarted?.call();
                (isLink
                        ? context.read<AuthCubit>().linkWithGoogle
                        : context.read<AuthCubit>().signInWithGoogle)()
                    .whenComplete(() => onSocialAuthEnded?.call());
              },
              assetPath: 'assets/images/login/google.svg',
            ),
        ],
      ),
    );
  }
}
