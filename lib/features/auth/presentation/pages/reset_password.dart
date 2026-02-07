import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/error/restart_widget.dart';

import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

class NewPasswordScreen extends StatefulWidget {
  final String phone;
  final String otp;

  const NewPasswordScreen({
    super.key,
    required this.phone,
    required this.otp,
  });

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.changePassword),
        centerTitle: true,
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthPasswordResetSuccess) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context); // Close loading
            }

            // Show success dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.passwordResetSuccessful,
                      style: AppTextStyles.bold18,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.pleaseLoginWithNewPassword,
                      style: AppTextStyles.regular14,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  AppCustomButton(
                    text: loc.signin,
                    onPressed: () {
                      RestartWidget.restartApp();
                    },
                  ),
                ],
              ),
            );
          } else if (state is AuthFailure) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context); // Close loading
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  loc.password,
                  style: AppTextStyles.bold18,
                ),
                const SizedBox(height: 8),
                Text(
                  loc.shortPassword,
                  style: AppTextStyles.regular14.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                AppTextFormField(
                  controller: newPasswordController,
                  label: loc.password ,
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return loc.enterPassword;
                    } else if (value.length < 6) {
                      return loc.shortPassword;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextFormField(
                  controller: confirmPasswordController,
                  label: loc.confirmPassword,
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return loc.enterPassword;
                    } else if (value != newPasswordController.text) {
                      return loc.passwordMismatch;
                    }
                    return null;
                  },
                ),
                const Spacer(),
                AppCustomButton(
                  isLoading: context.watch<AuthCubit>().state is AuthLoading,
                  text: loc.resetPassword,
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      context.read<AuthCubit>().resetPassword(
                        phone: widget.phone,
                        userOtp: widget.otp,
                        newPassword: newPasswordController.text.trim(),
                      );
                    }
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}