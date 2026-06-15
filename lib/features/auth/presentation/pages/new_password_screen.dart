import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/app_dynamic_settings.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

/// Combines OTP entry and new-password entry in one screen so the user
/// finds out immediately (on submit) whether the OTP is still valid.
class NewPasswordScreen extends StatefulWidget {
  /// Phone number OR email used to identify the account on the backend.
  final String identifier;

  /// Same as [identifier] — shown to the user so they know where the OTP went.
  final String destination;

  /// "phone" or "email" — used when requesting a resend.
  final String via;

  const NewPasswordScreen({
    super.key,
    required this.identifier,
    required this.destination,
    required this.via,
  });

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  late final int _otpLength = AppSettings.otp_length;

  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _secondsRemaining = AppSettings.otp_resend_duration_seconds;
  bool _canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = AppSettings.otp_resend_duration_seconds;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _canResend = true);
        t.cancel();
      }
    });
  }

  void _resend() {
    if (!_canResend) return;
    _otpController.clear();

    final isEmail = widget.via == 'email';
    context.read<AuthCubit>().forgotPassword(
      phone: isEmail ? null : widget.identifier,
      email: isEmail ? widget.identifier : null,
    );
    _startTimer();
  }

  void _submit() {
    final otp = _otpController.text.trim();
    if (otp.length != _otpLength) {
      showErrorBanner(context, 'Please enter the complete OTP');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    dLog('Resetting password with otp: $otp');
    context.read<AuthCubit>().resetPassword(
      identifier: widget.identifier,
      code: otp,
      password: _newPasswordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final defaultPin = PinTheme(
      width: 52,
      height: 56,
      textStyle: AppTextStyles.bold18.copyWith(color: Colors.black),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(loc.resetPassword), centerTitle: true),
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
          } else if (state is AuthForgotPasswordOtpSent) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            showSuccessBanner(context, state.message);
          } else if (state is AuthFailure) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            showErrorBanner(context, state.message);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

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
                  loc.enterOtpSent,
                  style: AppTextStyles.bold18,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  widget.destination,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bold16
                      .copyWith(color: AppColors.kPrimaryColor),
                ),
                const SizedBox(height: 24),

                Center(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Pinput(
                      length: _otpLength,
                      controller: _otpController,
                      focusNode: _otpFocusNode,
                      defaultPinTheme: defaultPin,
                      focusedPinTheme: defaultPin.copyDecorationWith(
                        border: Border.all(
                          color: AppColors.kPrimaryColor,
                          width: 2,
                        ),
                      ),
                      submittedPinTheme: defaultPin.copyWith(
                        decoration: defaultPin.decoration?.copyWith(
                          color: AppColors.kPrimaryColor.withOpacity(0.1),
                          border: Border.all(color: AppColors.kPrimaryColor),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: _canResend
                      ? TextButton(
                    onPressed: _resend,
                    child: Text(
                      loc.resendOtp,
                      style: AppTextStyles.bold14.copyWith(
                        color: AppColors.kPrimaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                      : Text(
                    '${loc.resendOtpIn} $_secondsRemaining ${loc.seconds}',
                    style: AppTextStyles.regular14
                        .copyWith(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  loc.enterPassword,
                  style: AppTextStyles.regular14.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                AppTextFormField(
                  controller: _newPasswordController,
                  label: loc.password,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) return loc.enterPassword;
                    if (value.length < 8) return loc.shortPassword;
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
