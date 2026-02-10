// social_auth_button_row.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/auth/presentation/widgets/social_button.dart';

import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/text_form.dart';
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
              onPressed: () {
                // Always show phone input first
                _showPhoneNumberBottomSheet(
                  context,
                  provider: 'apple',
                );
              },
              assetPath: 'assets/images/login/apple.svg',
            ),
          SocialLoginButton(
            title: AppLocalizations.of(context)!.googleSignin,
            onPressed: () {
              // Always show phone input first
              _showPhoneNumberBottomSheet(
                context,
                provider: 'google',
              );
            },
            assetPath: 'assets/images/login/google.svg',
          ),
        ],
      ),
    );
  }

  void _showPhoneNumberBottomSheet(
      BuildContext context, {
        required String provider,
      }) {
    final formKey = GlobalKey<FormState>();
    final TextEditingController phoneController = TextEditingController();
    final localizations = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizations.enterPhoneNumber, style: AppTextStyles.bold18),
              const SizedBox(height: 8),
              Text(
                localizations.weNeedYourPhoneNumber,
                style: AppTextStyles.regular14.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Form(
                key: formKey,
                child: AppTextFormField(
                  label: localizations.phone,
                  controller: phoneController,
                  isPhone: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return localizations.enterPhoneNumber;
                    } else if (v.length != 11 || !v.startsWith('01')) {
                      return localizations.invalidPhoneNumber;
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              AppCustomButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    String phone = phoneController.text.trim();
                    if (!phone.startsWith('+2')) {
                      phone = '+2$phone';
                    }

                    Navigator.pop(sheetContext);

                    // Call appropriate social auth method with phone
                    if (provider == 'google') {
                      context.read<AuthCubit>().signInWithGoogle();
                    } else if (provider == 'apple') {
                      context.read<AuthCubit>().signInWithApple();
                    }
                  }
                },
                text: localizations.confirm,
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                  },
                  child: Text(
                    localizations.cancel,
                    style: AppTextStyles.bold16,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}