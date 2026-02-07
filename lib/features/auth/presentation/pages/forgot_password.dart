import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.forgotPassword),
        centerTitle: true,
      ),
      body: BlocListener<AuthCubit, AuthState>(
    listener: (context, state) {
      log('ForgotPasswordScreen - State: ${state.runtimeType}');

      if (state is AuthForgotPasswordOtpSent) {
        log('OTP sent, navigating to verification screen');
        log('Phone: ${state.phone}');

        // Reset state immediately
        context.read<AuthCubit>().reset();

        // Navigate
        context.go('/auth/verify-otp-password-reset', extra: state.phone);
      } else if (state is AuthFailure) {
// Show error for other failures
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
          ),
        );      }
    },
    child: BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return _buildForm(context, loc, isLoading);
      },
    ),
    ),
    );
  }

  Widget _buildForm(
      BuildContext context,
      AppLocalizations loc,
      bool isLoading,
      ) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                Text(
                  loc.enterPhoneToResetPassword,
                  style: AppTextStyles.regular14.copyWith(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 32),

                AppTextFormField(
                  controller: phoneController,
                  label: loc.phone,
                  isPhone: true,
                  enabled: !isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return loc.enterPhoneNumber;
                    } else if (value.length != 11 || !value.startsWith('01')) {
                      return loc.invalidPhoneNumber;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                AppCustomButton(
                  text: loc.sendOtp ?? 'Send OTP',
                  isLoading: isLoading,
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      String phone = phoneController.text.trim();

                      if (!phone.startsWith('+2')) {
                        phone = '+2$phone';
                      }

                      log('Sending OTP request for phone: $phone');
                      context.read<AuthCubit>().forgotPassword(phone);
                    }
                  },
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),

        // // Loading overlay - positioned absolutely
        // if (isLoading)
        //   Positioned.fill(
        //     child: Container(
        //       color: Colors.black.withOpacity(0.3),
        //       child: const Center(
        //         child: LoadingScreen(),
        //       ),
        //     ),
        //   ),
      ],
    );
  }
}