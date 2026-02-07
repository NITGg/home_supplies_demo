import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  final bool isPasswordReset;

  const OtpVerificationScreen({
    super.key,
    required this.phone,
    this.isPasswordReset = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  int _secondsRemaining = 60;
  Timer? _timer;
  bool _canResend = false;
  bool _hasNavigated = false;
  bool _otpMessageShown = false;

  static const int _otpLength = 3;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // Reset cubit state once when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      log('OTP Screen initialized');
      log('Phone: ${widget.phone}');
      log('Is Password Reset: ${widget.isPasswordReset}');

      context.read<AuthCubit>().reset();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  // ================= Timer =================

  void _startTimer() {
    _secondsRemaining = 60;
    _canResend = false;
    _timer?.cancel();
    // Don't start timer here - let the widget handle it
    // The StatefulBuilder will manage the timer
  }

  // ================= Actions =================

  void _resendOtp() {
    if (!_canResend) return;

    log('Resending OTP for ${widget.phone}');

    if (!widget.isPasswordReset) {
      context.read<AuthCubit>().resendPhoneOtp(phone: widget.phone);
    } else {
      context.read<AuthCubit>().forgotPassword(widget.phone);
    }

    _startTimer();
    _otpMessageShown = false; // reset so SnackBar can show again
  }

  void _verifyOtp() {
    final otp = _otpController.text.trim();

    if (otp.length != _otpLength) {
      _showError('Please enter the complete OTP');
      return;
    }

    log('Verifying OTP: $otp for ${widget.phone}');

    if (!widget.isPasswordReset) {
      context.read<AuthCubit>().verifyPhoneOtp(
        phone: widget.phone,
        userOtp: otp,
      );
    } else {
      context.go(
        '/auth/new-password',
        extra: {'phone': widget.phone, 'otp': otp},
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ================= Bloc Handling =================

  void _handleState(BuildContext context, AuthState state) {
    log('OTP Screen - State changed to: ${state.runtimeType}');

    if (_hasNavigated) return;

    // Login success
    if (state is AuthSuccess && !widget.isPasswordReset) {
      _hasNavigated = true;
      context.go('/mainHome');
    }

    // OTP resent / Forgot password OTP sent
    else if ((state is AuthOtpResent || state is AuthForgotPasswordOtpSent) &&
        !_otpMessageShown) {
      _otpMessageShown = true;

      final message = state is AuthOtpResent
          ? state.message
          : (state as AuthForgotPasswordOtpSent).message;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }

    // Error
    else if (state is AuthFailure) {
      _showError(state.message);
    }
  }

  // ================= UI =================

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
      appBar: AppBar(
        title: Text(loc.verifyPhone),
        centerTitle: true,
      ),
      body:BlocConsumer<AuthCubit, AuthState>(
    listener: _handleState,
    builder: (context, state) {
      log('🔍 OTP Screen Builder - State: ${state.runtimeType}');

      final isLoading = state is AuthLoading;
      log('📊 OTP Screen - isLoading: $isLoading');

      return Stack(
        children: [
          Padding(
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
                  loc.enterOtpSent ?? 'Enter the OTP sent to',
                  style: AppTextStyles.bold18,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  widget.phone,
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.bold16
                      .copyWith(color: AppColors.kPrimaryColor),
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

                // Timer widget - wrapped to prevent unnecessary rebuilds
                _buildTimerWidget(loc, isLoading),

                const Spacer(),

                AppCustomButton(
                  text: loc.verify ?? 'Verify',
                  isLoading: isLoading,
                  onPressed: _verifyOtp,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      );
    },
    ),
    );
  }
  Widget _buildTimerWidget(AppLocalizations loc, bool isLoading) {
    // Use a StatefulBuilder to localize timer rebuilds
    return StatefulBuilder(
      builder: (context, setTimerState) {
        // Update the timer callback to use local setState
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
          '${loc.resendOtpIn} '
              '$_secondsRemaining '
              '${loc.seconds}',
          style: AppTextStyles.regular14.copyWith(color: Colors.grey),
        );
      },
    );
  }
}
