import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/app_dynamic_settings.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

/// New multi-channel OTP verification screen for registration / login.
///
/// NOT WIRED YET — backend doesn't require this flow. Built ahead of time so
/// it can be plugged in quickly once the new endpoints are required:
/// /auth/verify-account + /auth/request-verification, with OTP length and
/// resend countdown coming from [AppSettings.otp_length] /
/// [AppSettings.otp_resend_duration_seconds].
class AccountOtpVerificationScreen extends StatefulWidget {
  final String destination;
  final String channel; // 'phone' or 'email'

  const AccountOtpVerificationScreen({
    super.key,
    required this.destination,
    required this.channel,
  });

  @override
  State<AccountOtpVerificationScreen> createState() =>
      _AccountOtpVerificationScreenState();
}

class _AccountOtpVerificationScreenState
    extends State<AccountOtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  late int _otpLength;
  late int _resendSeconds;
  int _secondsRemaining = 0;
  Timer? _timer;
  bool _canResend = false;
  bool _hasNavigated = false;

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
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = _resendSeconds;
    _canResend = false;
    _timer?.cancel();
  }

  void _resendOtp() {
    if (!_canResend) return;

    _otpController.clear();
    dLog('Resending account verification code for ${widget.destination}');

    context.read<AuthCubit>().resendRegistrationVerification(
      phone: widget.channel == 'phone' ? widget.destination : null,
      email: widget.channel == 'email' ? widget.destination : null,
    );

    _startTimer();
  }

  void _verifyOtp() {
    final otp = _otpController.text.trim();

    if (otp.length != _otpLength) {
      showErrorBanner(context, 'Please enter the complete OTP');
      return;
    }

    dLog('Verifying account OTP: $otp for ${widget.destination}');

    context.read<AuthCubit>().verifyAccountOtp(
      phone: widget.destination,
      code: otp,
      channel: widget.channel,
    );
  }

  void _handleState(BuildContext context, AuthState state) {
    if (_hasNavigated) return;

    if (state is AuthSuccess) {
      _hasNavigated = true;
      context.go('/mainHome');
    } else if (state is AuthNextOtpRequired) {
      _hasNavigated = true;
      context.pushReplacement(
        '/auth/verify-account-otp',
        extra: {'destination': state.destination, 'channel': state.via},
      );
    } else if (state is AuthVerificationCodeResent) {
      showSuccessBanner(context, state.message);
    } else if (state is AuthFailure) {
      showErrorBanner(context, state.message);
    }
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

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.red, width: 2),
    );

    return Scaffold(
      appBar: AppBar(title: Text(loc.verifyPhone), centerTitle: true),
      body: SafeArea(
        top: false,
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: _handleState,
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  Lottie.asset(
                    'assets/animation_json/otp.json',
                    width: 120,
                    height: 120,
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
                    style: AppTextStyles.bold16.copyWith(
                      color: AppColors.kPrimaryColor,
                    ),
                  ),

                  const SizedBox(height: 40),

                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Pinput(
                      controller: _otpController,
                      focusNode: _otpFocusNode,
                      length: _otpLength,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                      submittedPinTheme: submittedPinTheme,
                      errorPinTheme: errorPinTheme,
                      showCursor: true,
                      enabled: !isLoading,
                      onCompleted: (_) {
                        if (!isLoading) _verifyOtp();
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildTimerWidget(loc, isLoading),

                  const Spacer(),

                  AppCustomButton(
                    text: loc.verify,
                    isLoading: isLoading,
                    onPressed: isLoading ? () {} : _verifyOtp,
                  ),

                  const SizedBox(height: 40),
                ],
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
