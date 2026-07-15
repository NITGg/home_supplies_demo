import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';
import 'package:tawreedat_courier/core/error/restart_widget.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/app_dynamic_settings.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

/// New combined OTP + new-password screen for the "forgot password" flow.
///
/// NOT WIRED YET — backend doesn't require this flow. Built ahead of time so
/// it can be plugged in quickly once /auth/verify-forget-password (combined
/// verify + reset) is required. Nothing currently navigates here.
class NewPasswordScreenV2 extends StatefulWidget {
  final String identifier;
  final String channel; // 'phone' or 'email'
  final String destination;

  const NewPasswordScreenV2({
    super.key,
    required this.identifier,
    required this.channel,
    required this.destination,
  });

  @override
  State<NewPasswordScreenV2> createState() => _NewPasswordScreenV2State();
}

class _NewPasswordScreenV2State extends State<NewPasswordScreenV2> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController =
      TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late int _otpLength;
  late int _resendSeconds;
  int _secondsRemaining = 0;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _otpLength = AppSettings.otp_length ?? 4;
    _resendSeconds = AppSettings.otp_resend_duration_seconds ?? 60;
    _secondsRemaining = _resendSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = _resendSeconds;
    _canResend = false;
    _timer?.cancel();
  }

  void _resendOtp() {
    if (!_canResend) return;
    context.read<AuthCubit>().forgotPassword(widget.identifier);
    _startTimer();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final otp = _otpController.text.trim();
    if (otp.length != _otpLength) {
      showErrorBanner(context, 'Please enter the complete OTP');
      return;
    }

    context.read<AuthCubit>().verifyForgetPasswordAndReset(
      identifier: widget.identifier,
      code: otp,
      password: _newPasswordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: AppTextStyles.bold18.copyWith(color: Colors.black),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.kPrimaryColor, width: 2),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: AppColors.kPrimaryColor.withOpacity(0.1),
        border: Border.all(color: AppColors.kPrimaryColor),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(loc.resetPassword), centerTitle: true),
      body: SafeArea(
        top: false,
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthPasswordResetSuccess) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Icon(
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
                      onPressed: () => RestartWidget.restartApp(),
                    ),
                  ],
                ),
              );
            } else if (state is AuthFailure) {
              showErrorBanner(context, state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
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
                      style: AppTextStyles.bold16.copyWith(
                        color: AppColors.kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Pinput(
                          controller: _otpController,
                          length: _otpLength,
                          defaultPinTheme: defaultPinTheme,
                          focusedPinTheme: focusedPinTheme,
                          submittedPinTheme: submittedPinTheme,
                          showCursor: true,
                          enabled: !isLoading,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(child: _buildTimerWidget(loc, isLoading)),
                    const SizedBox(height: 32),
                    Text(loc.password, style: AppTextStyles.bold18),
                    const SizedBox(height: 8),
                    Text(
                      loc.shortPassword,
                      style: AppTextStyles.regular14.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      controller: _newPasswordController,
                      label: loc.password,
                      isPassword: true,
                      enabled: !isLoading,
                      validator: (v) {
                        if (v == null || v.isEmpty) return loc.enterPassword;
                        if (v.length < 6) return loc.shortPassword;
                        if (!RegExp(r'[A-Z]').hasMatch(v)) {
                          return loc.passwordNeedsUppercase;
                        }
                        if (!RegExp(r'[a-z]').hasMatch(v)) {
                          return loc.passwordNeedsLowercase;
                        }
                        if (!RegExp(r'[0-9]').hasMatch(v)) {
                          return loc.passwordNeedsNumber;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      controller: _confirmPasswordController,
                      label: loc.confirmPassword,
                      isPassword: true,
                      enabled: !isLoading,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return loc.enterPassword;
                        } else if (value != _newPasswordController.text) {
                          return loc.passwordMismatch;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    AppCustomButton(
                      isLoading: isLoading,
                      text: loc.resetPassword,
                      onPressed: isLoading ? () {} : _submit,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimerWidget(AppLocalizations loc, bool isLoading) {
    return StatefulBuilder(
      builder: (context, setTimerState) {
        if (_timer == null || !_timer!.isActive) {
          _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (_secondsRemaining > 0) {
              setTimerState(() => _secondsRemaining--);
            } else {
              setTimerState(() => _canResend = true);
              timer.cancel();
            }
          });
        }

        return _canResend
            ? TextButton(
                onPressed: isLoading ? null : _resendOtp,
                child: Text(
                  loc.resendOtp,
                  style: AppTextStyles.bold14.copyWith(
                    color: isLoading ? Colors.grey : AppColors.kPrimaryColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              )
            : Text(
                '${loc.resendOtpIn} $_secondsRemaining ${loc.seconds}',
                style: AppTextStyles.regular14.copyWith(color: Colors.grey),
              );
      },
    );
  }
}
