
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

/// Receives `extra: {'otp': String}` from GoRouter.
class NewPasswordScreen extends StatefulWidget {
  final String otp;

  const NewPasswordScreen({super.key, required this.otp});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    dLog('Resetting password with otp: ${widget.otp}');
    context.read<AuthCubit>().resetPassword(
      code: widget.otp,
      password: _newPasswordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.password), centerTitle: true),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthLoading) {
            showDialog(
              useSafeArea: false,
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(child: LoadingScreen()),
            );
          } else if (state is AuthUpdateSuccess) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            showSuccessBanner(context, loc.passwordResetSuccessful);
            context.go('/auth/login');
          } else if (state is AuthFailure) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            showErrorBanner(context, state.message);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.kPrimaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_reset_rounded,
                      size: 48,
                      color: AppColors.kPrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  loc.enterPassword,
                  style: AppTextStyles.regular14.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                AppTextFormField(
                  controller: _newPasswordController,
                  label: loc.password,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) return loc.enterPassword;
                    if (value.length < 6) return loc.shortPassword;
                    if (!RegExp(r'[A-Z]').hasMatch(value)) return loc.passwordNeedsUppercase;
                    if (!RegExp(r'[a-z]').hasMatch(value)) return loc.passwordNeedsLowercase;
                    if (!RegExp(r'[0-9]').hasMatch(value)) return loc.passwordNeedsNumber;
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                AppTextFormField(
                  controller: _confirmPasswordController,
                  label: loc.confirmPassword,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) return loc.enterPassword;
                    if (value != _newPasswordController.text) {
                      return loc.passwordMismatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                AppCustomButton(text: loc.confirm, onPressed: _submit),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}